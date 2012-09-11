require_relative 'visitor'

require 'llvm/core'
require 'llvm/execution_engine'
require 'llvm/transforms/scalar'

LLVM.init_x86

module Crystal
  def run(code)
    node = parse code
    type node

    visitor = CodeGenVisitor.new
    node.accept visitor

    # visitor.mod.dump

    engine = LLVM::JITCompiler.new(visitor.mod)
    engine.run_function visitor.main
  end

  class CodeGenVisitor < Visitor
    attr_reader :mod
    attr_reader :main

    def initialize
      @mod = LLVM::Module.new("Crystal")
      @main = @mod.functions.add("main", [], LLVM::Int)
      @entry = @main.basic_blocks.append("entry")
      @builder = LLVM::Builder.new
      @builder.position_at_end(@entry)
    end

    def end_visit_expressions(node)
      @builder.ret @last
    end

    def visit_int(node)
      @last = LLVM::Int(node.value.to_i)
    end
  end
end