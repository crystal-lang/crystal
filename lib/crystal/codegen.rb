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
    def mangled_name
      self.class.mangled_name(owner, name, args.map(&:type))
    end

    def self.mangled_name(owner, name, arg_types)
      str = ''
      if owner
        str << owner.to_s
        str << '#'
      end
      str << name.to_s
      if arg_types.length > 0
        str << '<'
        str << arg_types.map(&:name).join(', ')
        str << '>'
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

    def visit_bool(node)
      @last = LLVM::Int1.from_i(node.value ? 1 : 0)
    end

    def visit_int(node)
      @last = LLVM::Int(node.value)
    end

    def visit_float(node)
      @last = LLVM::Float(node.value)
    end

    def visit_char(node)
      @last = LLVM::Int8.from_i(node.value)
    end

    def visit_assign(node)
      node.value.accept self

      if node.target.is_a?(InstanceVar)
        ptr = gep @fun.params[0], 0, @type.index_of_instance_var(node.target.name)
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

      if node.target.type == node.value.type
        @builder.store @last, ptr
      else
        assign_to_union(ptr, node.target.type, node.value.type, @last)
      end

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
      index = @type.index_of_instance_var(node.name)
      struct = @builder.load @fun.params[0]
      @last = @builder.extract_value struct, index, node.name
    end

    def visit_if(node)
      has_else = !node.else.empty?

      then_block, exit_block = new_blocks "then", "exit"
      else_block = new_block "else" if has_else

      node.cond.accept self

      @builder.cond(@last, then_block, has_else ? else_block : exit_block)

      @builder.position_at_end then_block
      node.then.accept self
      then_value = @last
      @builder.br exit_block

      if has_else
        @builder.position_at_end else_block
        node.else.accept self
        else_value = @last
        @builder.br exit_block

        @builder.position_at_end exit_block
        @last = @builder.phi node.llvm_type, {then_block => then_value, else_block => else_value}
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

    def visit_call(node)
      if node.obj.is_a?(Const) && node.name == 'new'
        @last = @builder.malloc(node.type.llvm_struct_type)
        return false
      end

      if node.target_def.is_a?(Dispatch)
        codegen_dispatch(node)
        return false
      end

      call_args = []
      if node.obj
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

    def codegen_call(target_def, obj_type, call_args)
      mangled_name = target_def.mangled_name

      old_fun = @fun
      unless @fun = @funs[mangled_name]
        old_position = @builder.insert_block
        old_vars = @vars
        old_type = @type

        @vars = {}

        args = []
        if obj_type
          @type = obj_type
          args << Var.new("self", obj_type)
        end
        args += target_def.args

        @fun = @funs[mangled_name] = @llvm_mod.functions.add(
          mangled_name,
          args.map(&:llvm_type),
          target_def.body.llvm_type
        )

        args.each_with_index do |arg, i|
          @fun.params[i].name = arg.name
        end

        unless target_def.is_a? External
          @fun.linkage = :internal
          new_entry_block

          args.each_with_index do |arg, i|
            if obj_type && i == 0 || target_def.body.is_a?(PrimitiveBody)
              @vars[arg.name] = { ptr: @fun.params[i], type: arg.type, is_arg: true }
            else
              ptr = @builder.alloca(arg.llvm_type, arg.name)
              @vars[arg.name] = { ptr: ptr, type: arg.type }
              @builder.store @fun.params[i], ptr
            end
          end

          target_def.body.accept self
          @builder.ret(target_def.body.type == @mod.void ? nil : @last)
          @builder.position_at_end old_position
        end

        @vars = old_vars
        @type = old_type
      end

      @last = @builder.call @fun, *call_args
      @fun = old_fun
    end

    def codegen_dispatch(node)
      dispatch = node.target_def

      unreachable_block, exit_block = new_blocks "unreachable", "exit"

      phi_table = {}
      arg_types = []
      arg_values = []

      codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block) do |label|
        call = dispatch.calls[arg_types]
        codegen_call(call.target_def, arg_types[0], arg_values)

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
      arg.accept self

      if arg.type.is_a?(UnionType)
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
        codegen_dispatch_next_arg node, arg_types, arg_values, arg.type, @last, unreachable_block, arg_index, previous_label, &block
      end
    end

    def codegen_dispatch_next_arg(node, arg_types, arg_values, arg_type, arg_value, unreachable_block, arg_index, label, &block)
      arg_types.push arg_type
      arg_values.push arg_value

      if arg_index == node.args.length - 1
        block.call(label)
      else
        codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block, arg_index + 1, label, &block)
      end

      arg_types.pop
      arg_values.pop
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