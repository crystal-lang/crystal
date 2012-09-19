require 'llvm/core'
require 'llvm/execution_engine'
require 'llvm/transforms/scalar'

LLVM.init_x86

module Crystal
  class Def
    def mangled_name
      self.class.mangled_name(owner, name, args.map(&:type))
    end

    def self.mangled_name(owner, name, arg_types)
      mangled_args = arg_types.map(&:name).join ', '
      if owner
        "#{owner.name}##{name}<#{mangled_args}>"
      else
        "#{name}<#{mangled_args}>"
      end
    end
  end

  def run(code)
    mod = build code

    engine = LLVM::JITCompiler.new(mod)
    engine.run_function mod.functions["main"]
  end

  def build(code)
    node = parse code
    mod = type node

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
      @llvm_mod = LLVM::Module.new("Crystal")
      @fun = @llvm_mod.functions.add("main", [], return_type.llvm_type)
      entry = @fun.basic_blocks.append("entry")
      @builder = LLVM::Builder.new
      @builder.position_at_end(entry)

      @funs = {}
      @vars = {}
    end

    def main
      @fun
    end

    def finish
      @builder.ret @last
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

      var = @vars[node.target.name]
      unless var && var[:type] == node.type
        var = @vars[node.target.name] = {
          ptr: @builder.alloca(node.type.llvm_type, node.target.name),
          type: node.type
        }
      end

      @builder.store @last, var[:ptr]

      false
    end

    def visit_var(node)
      var = @vars[node.name]
      if var[:is_arg]
        @last = var[:ptr]
      else
        @last = @builder.load var[:ptr], node.name
      end
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
      @builder.br exit_block

      if has_else
        @builder.position_at_end else_block
        node.else.accept self
        @builder.br exit_block
      end

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
      @last = node.block.call(@builder, Hash[@vars.map { |k, v| [k, v[:ptr]] }])
    end

    def visit_call(node)
      mangled_name = node.target_def.mangled_name

      old_fun = @fun
      unless @fun = @funs[mangled_name]
        old_position = @builder.insert_block
        old_vars = @vars

        @vars = {}

        args = []
        if node.obj
          self_var = Var.new("self")
          self_var.type = node.obj.type
          args << self_var
        end
        args += node.target_def.args

        @fun = @funs[mangled_name] = @llvm_mod.functions.add(
          mangled_name,
          args.map { |arg| arg.type.llvm_type },
          node.target_def.body.type.llvm_type
        )

        args.each_with_index do |arg, i|
          param = @fun.params[i]
          param.name = arg.name

          @vars[param.name] = {type: arg.type, ptr: param, is_arg: true}
        end

        unless node.target_def.is_a? External
          entry = @fun.basic_blocks.append("entry")
          @builder.position_at_end(entry)
          node.target_def.body.accept self
          @builder.ret @last
          @builder.position_at_end old_position
        end

        @vars = old_vars
      end

      values = []
      if node.obj
        node.obj.accept self
        values << @last
      end
      node.args.each do |arg|
        arg.accept self
        values << @last
      end

      @last = @builder.call @fun, *values, mangled_name
      @fun = old_fun

      false
    end
  end
end