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
      entry = @fun.basic_blocks.append("entry")
      @builder = LLVM::Builder.new
      @builder.position_at_end(entry)

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
        index = @type.index_of_instance_var(node.target.name)
        ptr = @builder.gep(@fun.params[0], [LLVM::Int(0), LLVM::Int(index)], node.target.name)
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
        index = node.target.type.index_of_type(node.value.type)
        index_ptr = @builder.gep ptr, [LLVM::Int(0), LLVM::Int(0)]
        @builder.store LLVM::Int(index), index_ptr

        value_ptr = @builder.gep ptr, [LLVM::Int(0), LLVM::Int(1)]
        casted_value_ptr = @builder.bit_cast value_ptr, LLVM::Pointer(node.value.llvm_type)
        @builder.store @last, casted_value_ptr
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

      then_block = @fun.basic_blocks.append("then")
      exit_block = @fun.basic_blocks.append("exit")

      if has_else
        else_block = @fun.basic_blocks.append("else")
      end

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
      while_block = @fun.basic_blocks.append("while")
      body_block = @fun.basic_blocks.append("body")
      exit_block = @fun.basic_blocks.append("exit")

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
          entry = @fun.basic_blocks.append("entry")
          @builder.position_at_end(entry)

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

      unreachable_block = @fun.basic_blocks.append("unreachable")
      exit_block = @fun.basic_blocks.append("exit")

      phi_table = {}

      if dispatch.obj && dispatch.obj.is_a?(UnionType)
        node.obj.accept self
        obj_ptr = @last
        type_index_ptr = @builder.gep obj_ptr, [LLVM::Int(0), LLVM::Int(0)]
        value_ptr = @builder.gep obj_ptr, [LLVM::Int(0), LLVM::Int(1)]

        switch_table = {}

        old_block = @builder.insert_block
        dispatch.obj.types.each_with_index.each do |obj_type, i|
          label = @fun.basic_blocks.append("obj_type_#{i}")
          @builder.position_at_end label

          casted_value_ptr = @builder.bit_cast value_ptr, LLVM::Pointer(obj_type.llvm_type)
          value = @builder.load casted_value_ptr

          call = dispatch.calls[[obj_type, []]]
          codegen_call(call.target_def, obj_type, [value])

          @builder.br exit_block

          switch_table[LLVM::Int(i)] = label
          phi_table[label] = @last
        end
        @builder.position_at_end old_block

        type_index = @builder.load type_index_ptr
        @builder.switch type_index, unreachable_block, switch_table
      end

      @builder.position_at_end unreachable_block
      @builder.unreachable

      @builder.position_at_end exit_block
      @last = @builder.phi dispatch.llvm_type, phi_table

      false
    end
  end
end