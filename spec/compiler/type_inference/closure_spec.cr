#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: closure" do
  it "gives error when doing yield inside fun literal" do
    assert_error "-> { yield }", "can't yield from function literal"
  end

  it "marks variable as closured in program" do
    result = assert_type("x = 1; -> { x }; x") { int32 }
    node = result.node as Expressions
    assign = node.expressions.first as Assign
    var = assign.target as Var
    meta_var = var.dependencies.first as Var
    meta_var.closured.should be_true
    result.program.closured_vars.should eq([meta_var])
  end

  it "marks variable as closured in def" do
    result = assert_type("def foo; x = 1; -> { x }; 1; end; foo") { int32 }
    node = result.node as Expressions
    call = node.expressions.last as Call
    target_def = call.target_def
    assign = (target_def.body as Expressions).expressions.first as Assign
    var = assign.target as Var
    meta_var = var.dependencies.first as Var
    meta_var.closured.should be_true
    call.target_def.closured_vars.should eq([meta_var])
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
    assign = (block.body as Expressions).expressions.first as Assign
    var = assign.target as Var
    meta_var = var.dependencies.first as Var
    meta_var.closured.should be_true

    block.closured_vars.should eq([meta_var])
  end
end
