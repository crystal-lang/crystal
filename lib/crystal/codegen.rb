require 'llvm/core'
require 'llvm/execution_engine'
require 'llvm/transforms/scalar'

LLVM.init_x86

module Crystal
  class ASTNode
    def llvm_type
      type ? type.llvm_type : LLVM.Void
    end
  end

  class Def
    def mangled_name(self_type)
      self.class.mangled_name(self_type, owner, name, (body ? body.type : nil), args.map(&:type))
    end

    def self.mangled_name(self_type, owner, name, return_type, arg_types)
      str = ''
      if self_type
        str << self_type.llvm_name
        str << '#'
      elsif owner
        if owner.is_a?(Metaclass)
          str << owner.type.name
          str << '::'
        elsif !owner.is_a?(Crystal::Module)
          str << owner.llvm_name
          str << '#'
        end
      end
      str << name.to_s.gsub('@', '.')
      if arg_types.length > 0
        str << '<'
        str << arg_types.map(&:llvm_name).join(', ')
        str << '>'
      end
      if return_type
        str << ':'
        str << return_type.llvm_name
      end
      str
    end
  end

  def run(code)
    node = parse code
    mod = infer_type node
    llvm_mod = build node, mod

    engine = LLVM::JITCompiler.new(llvm_mod)
    engine.run_function llvm_mod.functions["crystal_main"]
  end

  def build(node, mod)
    visitor = CodeGenVisitor.new(mod, node.type)
    node.accept visitor

    visitor.finish

    visitor.llvm_mod.verify

    visitor.llvm_mod.dump if ENV['DUMP']

    visitor.llvm_mod
  end

  class CodeGenVisitor < Visitor
    attr_reader :llvm_mod

    def initialize(mod, return_type)
      @mod = mod
      @return_type = return_type
      @llvm_mod = LLVM::Module.new("Crystal")
      @fun = @llvm_mod.functions.add("crystal_main", [], return_type ? return_type.llvm_type : LLVM.Void)
      @builder = LLVM::Builder.new

      new_entry_block

      @funs = {}
      @vars = {}
      @type = @mod
    end

    def main
      @fun
    end

    def finish
      @builder.ret(@return_type == @mod.void ? nil : @last)
    end

    def visit_bool_literal(node)
      @last = LLVM::Int1.from_i(node.value ? 1 : 0)
    end

    def visit_int_literal(node)
      @last = LLVM::Int(node.value)
    end

    def visit_float_literal(node)
      @last = LLVM::Float(node.value)
    end

    def visit_char_literal(node)
      @last = LLVM::Int8.from_i(node.value)
    end

    def visit_string_literal(node)
      @last = @builder.global_string_pointer(node.value)
    end

    def visit_assign(node)
      node.value.accept self

      if node.target.is_a?(InstanceVar)
        ivar = @type.instance_vars[node.target.name]
        if ivar.type.is_a?(UnionType)
          ptr = gep @fun.params[0], 0, @type.index_of_instance_var(node.target.name)
          assign_to_union(ptr, ivar.type, node.type, @last)

          return false
        else
          ptr = gep @fun.params[0], 0, @type.index_of_instance_var(node.target.name)
        end
      else
        var = @vars[node.target.name]
        unless var
          var = @vars[node.target.name] = {
            ptr: @builder.alloca(node.target.llvm_type, node.target.name),
            type: node.target.type
          }
        end
        ptr = var[:ptr]
      end

      codegen_assign(ptr, node.target.type, node.value.type, @last)

      false
    end

    def visit_var(node)
      var = @vars[node.name]
      if var[:is_arg] || var[:type].is_a?(UnionType)
        @last = var[:ptr]
      else
        @last = @builder.load var[:ptr], node.name
      end
    end

    def visit_instance_var(node)
      ivar = @type.instance_vars[node.name]
      if ivar.type.is_a?(UnionType)
        @last = gep @fun.params[0], 0, @type.index_of_instance_var(node.name)
      else
        index = @type.index_of_instance_var(node.name)
        struct = @builder.load @fun.params[0]
        @last = @builder.extract_value struct, index, node.name
      end
    end

    def visit_if(node)
      is_union = node.else && node.type.is_a?(UnionType)

      then_block, exit_block = new_blocks "then", "exit"
      else_block = new_block "else" if node.else

      union_ptr = @builder.alloca node.llvm_type if is_union
      node.cond.accept self

      @builder.cond(@last, then_block, node.else ? else_block : exit_block)

      @builder.position_at_end then_block
      node.then.accept self
      then_block = @builder.insert_block

      then_value = @last
      codegen_assign(union_ptr, node.type, node.then.type, @last) if is_union

      @builder.br exit_block

      if node.else
        @builder.position_at_end else_block
        node.else.accept self
        else_block = @builder.insert_block
        
        else_value = @last
        codegen_assign(union_ptr, node.type, node.else.type, @last) if is_union

        @builder.br exit_block

        @builder.position_at_end exit_block

        if is_union
          @last = union_ptr
        else
          @last = @builder.phi node.llvm_type, {then_block => then_value, else_block => else_value}
        end
      else
        @builder.position_at_end exit_block
      end

      false
    end

    def visit_while(node)
      while_block, body_block, exit_block = new_blocks "while", "body", "exit"

      @builder.br while_block

      @builder.position_at_end while_block
      node.cond.accept self

      @builder.cond(@last, body_block, exit_block)

      @builder.position_at_end body_block
      node.body.accept self
      @builder.br while_block

      @builder.position_at_end exit_block

      false
    end

    def visit_def(node)
      false
    end

    def visit_class_def(node)
      false
    end

    def visit_primitive_body(node)
      @last = node.block.call(@builder, @fun)
    end

    def visit_alloc(node)
      @last = @builder.malloc(node.type.llvm_struct_type)
    end

    def visit_call(node)
      if node.target_def.is_a?(Dispatch)
        codegen_dispatch(node)
        return false
      end

      call_args = []
      if node.obj && !node.obj.type.is_a?(Metaclass)
        node.obj.accept self
        call_args << @last
      end
      node.args.each do |arg|
        arg.accept self
        call_args << @last
      end

      codegen_call(node.target_def, node.obj && node.obj.type, call_args)

      false
    end

    def codegen_call(target_def, self_type, call_args)
      mangled_name = target_def.mangled_name(self_type)

      old_fun = @fun
      unless @fun = @funs[mangled_name]
        old_position = @builder.insert_block
        old_vars = @vars
        old_type = @type

        @vars = {}

        args = []
        if self_type && !self_type.is_a?(Metaclass)
          @type = self_type
          args << Var.new("self", self_type)
        end
        args += target_def.args

        @fun = @funs[mangled_name] = @llvm_mod.functions.add(
          mangled_name,
          args.map(&:llvm_type),
          (target_def.body ? target_def.body.llvm_type : LLVM.Void)
        )

        args.each_with_index do |arg, i|
          @fun.params[i].name = arg.name
        end

        unless target_def.is_a? External
          @fun.linkage = :internal
          new_entry_block

          args.each_with_index do |arg, i|
            if self_type && i == 0 || target_def.body.is_a?(PrimitiveBody)
              @vars[arg.name] = { ptr: @fun.params[i], type: arg.type, is_arg: true }
            else
              ptr = @builder.alloca(arg.llvm_type, arg.name)
              @vars[arg.name] = { ptr: ptr, type: arg.type }
              @builder.store @fun.params[i], ptr
            end
          end

          if target_def.body
            target_def.body.accept self
            if target_def.body.type.is_a?(UnionType)
              @last = @builder.load @last
            end

            @builder.ret(target_def.body.type == @mod.void ? nil : @last)
          else
            @builder.ret_void
          end

          @builder.position_at_end old_position
        end

        @vars = old_vars
        @type = old_type
      end

      @last = @builder.call @fun, *call_args

      if target_def.body && target_def.body.type.is_a?(UnionType)
        alloca = @builder.alloca target_def.body.llvm_type
        @builder.store @last, alloca
        @last = alloca
      end

      @fun = old_fun
    end

    def codegen_dispatch(node)
      dispatch = node.target_def

      unreachable_block, exit_block = new_blocks "unreachable", "exit"

      phi_table = {}
      arg_types = []
      arg_values = []

      codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block) do |label|
        call = dispatch.calls[arg_types.map(&:object_id)]
        codegen_call(call.target_def, (node.obj ? arg_types[0] : nil), arg_values)

        if dispatch.type.is_a?(UnionType)
          phi_table[label] = phi_value = @builder.alloca dispatch.llvm_type
          assign_to_union(phi_value, dispatch.type, call.type, @last)
        else
          phi_table[label] = @last
        end

        @builder.br exit_block
      end

      @builder.position_at_end unreachable_block
      @builder.unreachable

      @builder.position_at_end exit_block

      if dispatch.type.is_a?(UnionType)
        @last = @builder.phi LLVM::Pointer(dispatch.llvm_type), phi_table
      else
        @last = @builder.phi dispatch.llvm_type, phi_table
      end

      false
    end

    def codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block, arg_index = -1, previous_label = nil, &block)
      arg = arg_index == -1 ? node.obj : node.args[arg_index]
      arg.accept self if arg

      if arg && arg.type.is_a?(UnionType)
        arg_ptr = @last
        index_ptr, value_ptr = union_index_and_value(arg_ptr)

        switch_table = {}

        old_block = @builder.insert_block
        arg.type.types.each_with_index.each do |arg_type, i|
          label = new_block "type_#{i}"
          @builder.position_at_end label

          casted_value_ptr = @builder.bit_cast value_ptr, LLVM::Pointer(arg_type.llvm_type)
          value = @builder.load casted_value_ptr

          codegen_dispatch_next_arg node, arg_types, arg_values, arg_type, value, unreachable_block, arg_index, label, &block

          switch_table[LLVM::Int(i)] = label
        end

        @builder.position_at_end old_block

        type_index = @builder.load index_ptr
        @builder.switch type_index, unreachable_block, switch_table
      else
        codegen_dispatch_next_arg node, arg_types, arg_values, (arg ? arg.type : nil), @last, unreachable_block, arg_index, previous_label, &block
      end
    end

    def codegen_dispatch_next_arg(node, arg_types, arg_values, arg_type, arg_value, unreachable_block, arg_index, label, &block)
      arg_types.push arg_type
      arg_values.push arg_value unless arg_index == -1 && !node.obj

      if arg_index == node.args.length - 1
        block.call(label)
      else
        codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block, arg_index + 1, label, &block)
      end

      arg_types.pop
      arg_values.pop
    end

    def codegen_assign(pointer, target_type, value_type, value)
      if target_type == value_type
        if target_type.is_a?(UnionType)
          @last = @builder.load @last
          @builder.store @last, pointer
        else
          @builder.store value, pointer
        end
      else
        assign_to_union(pointer, target_type, value_type, value)
      end
    end

    def assign_to_union(union_pointer, union_type, type, value)
      index_ptr, value_ptr = union_index_and_value(union_pointer)

      index = union_type.index_of_type(type)
      @builder.store LLVM::Int(index), index_ptr

      casted_value_ptr = @builder.bit_cast value_ptr, LLVM::Pointer(type.llvm_type)
      @builder.store value, casted_value_ptr
    end

    def union_index_and_value(union_pointer)
      index_ptr = gep union_pointer, 0, 0
      value_ptr = gep union_pointer, 0, 1
      [index_ptr, value_ptr]
    end

    def gep(ptr, *indices)
      @builder.gep ptr, indices.map { |i| LLVM::Int(i) }
    end

    def new_block(name)
      @fun.basic_blocks.append(name)
    end

    def new_entry_block
      @builder.position_at_end(new_block "entry")
    end

    def new_blocks(*names)
      names.map { |name| new_block name }
    end
  end
end