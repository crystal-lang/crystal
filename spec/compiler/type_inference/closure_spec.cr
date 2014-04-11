#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: closure" do
  it "gives error when doing yield inside fun literal" do
    assert_error "-> { yield }", "can't yield from function literal"
  end

  it "marks variable as closured in program" do
    result = assert_type("x = 1; -> { x }; x") { int32 }
    program = result.program
    var = program.vars["x"]
    var.closured.should be_true
  end

  it "marks variable as closured in program on assign" do
    result = assert_type("x = 1; -> { x = 1 }; x") { int32 }
    program = result.program
    var = program.vars["x"]
    var.closured.should be_true
  end

  it "marks variable as closured in def" do
    result = assert_type("def foo; x = 1; -> { x }; 1; end; foo") { int32 }
    node = result.node as Expressions
    call = node.expressions.last as Call
    target_def = call.target_def
    var = target_def.vars.not_nil!["x"]
    var.closured.should be_true
  end

  it "marks variable as closured in block" do
    result = assert_type("
      def foo
        yield
      end

      foo do
        x = 1
        -> { x }
        1
      end
      ") { int32 }
    node = result.node as Expressions
    call = node.expressions.last as Call
    block = call.block.not_nil!
    var = block.before_vars.not_nil!["x"]
    var.closured.should be_true
  end

  it "transforms block to fun literal" do
    assert_type("
      def foo(&block : Int32 ->)
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ") { float64 }
  end
end
