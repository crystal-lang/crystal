require "parser"
require "type_inference"
require "visitor"
require "llvm"

LLVM.init_x86

module Crystal
  DUMP_LLVM = ENV["DUMP"] == "1"

  def run(code)
    node = Parser.parse(code)
    mod = infer_type node
    evaluate node, mod
  end

  def evaluate(node, mod)
    llvm_mod = build node, mod
    engine = LLVM::JITCompiler.new(llvm_mod)
    engine.run_function llvm_mod.functions["crystal_main"] #, 0, nil
  end

  def build(node, mod)
    visitor = CodeGenVisitor.new(mod, node)
    node.accept visitor
    visitor.finish
    visitor.llvm_mod.dump if Crystal::DUMP_LLVM
    visitor.llvm_mod
  end

  class CodeGenVisitor < Visitor
    attr_reader :llvm_mod
    attr_reader :fun

    def initialize(mod, node)
      @mod = mod
      @node = node
      @llvm_mod = LLVM::Module.new("Crystal")
      ret_type = node.type.llvm_type
      @fun = @llvm_mod.functions.add("crystal_main", [], ret_type.is_a?(LLVM::Type) ? ret_type : LLVM::Void)

      @builder = LLVM::Builder.new
      entry_block_chain = new_entry_block_chain ["alloca", "const", "entry"]
      @alloca_block, @const_block, @entry_block = entry_block_chain[0], entry_block_chain[1], entry_block_chain[2]
      @const_block_entry = @const_block
    end

    def finish
      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]
      last = @last
      last.is_a?(LibLLVM::ValueRef) ? @builder.ret(last) : @builder.ret

      @fun = @llvm_mod.functions.add "main", [], LLVM::Int32
      entry = new_block "entry"
      @builder.position_at_end entry
      @builder.call @llvm_mod.functions["crystal_main"]
      @builder.ret LLVM::Int32.from_i(0)
    end

    def visit(node : IntLiteral)
      @last = LLVM::Int32.from_i(node.value.to_i)
    end

    def visit(node : BoolLiteral)
      @last = LLVM::Int1.from_i(node.value ? 1 : 0)
    end

    def visit(node : LongLiteral)
      @last = LLVM::Int64.from_i(node.value.to_i)
    end

    def visit(node : FloatLiteral)
      @last = LLVM::Float.from_s(node.value)
    end

    # def new_entry_block
    #   @alloca_block, @entry_block = new_entry_block_chain "alloca", "entry"
    # end

    def new_entry_block_chain names
      blocks = new_blocks names
      @builder.position_at_end blocks.last
      blocks
    end

    # def br_from_alloca_to_entry
    #   br_block_chain @alloca_block, @entry_block
    # end

    def br_block_chain blocks
      old_block = @builder.insert_block

      0.upto(blocks.count - 2) do |i|
        @builder.position_at_end blocks[i]
        @builder.br blocks[i + 1]
      end

      @builder.position_at_end old_block
    end

    def new_block(name)
      @fun.append_basic_block(name)
    end

    def new_blocks(names)
      names.map { |name| new_block name }
    end
  end
end