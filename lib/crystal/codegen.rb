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

    visitor.llvm_mod.verify

    visitor.llvm_mod.dump if ENV['DUMP']

    visitor.llvm_mod
  end

  class CodeGenVisitor < Visitor
    attr_reader :llvm_mod
    attr_reader :main

    def initialize(mod, return_type)
      @mod = mod
      @llvm_mod = LLVM::Module.new("Crystal")
      @main = @llvm_mod.functions.add("main", [], return_type.llvm_type)
      entry = @main.basic_blocks.append("entry")
      @builder = LLVM::Builder.new
      @builder.position_at_end(entry)

      @funs = {}
      @vars = {}

      define_primitive(mod.int, :+, [mod.int], mod.int) do |f, x, y|
        f.basic_blocks.append("entry").build { |b| b.ret b.add(x, y) }
      end

      @funs['putchar<Char>'] = @llvm_mod.functions.add('putchar', [mod.char.llvm_type], mod.char.llvm_type)
    end

    def define_primitive(owner, name, arg_types, return_type, &block)
      mangled_name = Def.mangled_name(owner, name, arg_types)
      arg_types.insert 0, owner
      @funs[mangled_name] = @llvm_mod.functions.add(mangled_name, arg_types.map(&:llvm_type), return_type.llvm_type, &block)
    end

    def end_visit_expressions(node)
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

    def visit_def(node)
      false
    end

    def visit_class_def(node)
      false
    end

    def visit_call(node)
      mangled_name = node.target_def.mangled_name
      unless fun = @funs[mangled_name]
        old_position = @builder.insert_block
        old_vars = @vars
        @vars = {}

        fun = @funs[mangled_name] = @llvm_mod.functions.add(
          mangled_name,
          node.target_def.args.map { |arg| arg.type.llvm_type },
          node.target_def.body.type.llvm_type
        )
        node.target_def.args.each_with_index do |arg, i|
          param = fun.params[i]
          param.name = arg.name

          @vars[param.name] = {type: arg.type, ptr: param, is_arg: true}
        end

        entry = fun.basic_blocks.append("entry")
        @builder.position_at_end(entry)
        node.target_def.body.accept self
        @builder.position_at_end old_position
        @vars = old_vars
      end

      values = node.args.map do |arg|
        arg.accept self
        @last
      end

      if node.obj
        node.obj.accept self
        values.insert 0, @last
      end

      @last = @builder.call fun, *values, mangled_name
      false
    end
  end
end