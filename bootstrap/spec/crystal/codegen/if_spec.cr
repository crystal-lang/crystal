#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Code gen: if" do
  it "codegens if without an else with true" do
    run("a = 1; if true; a = 2; end; a").to_i.should eq(2)
  end

  it "codegens if without an else with false" do
    run("a = 1; if false; a = 2; end; a").to_i.should eq(1)
  end

  it "codegens if with an else with false" do
    run("a = 1; if false; a = 2; else; a = 3; end; a").to_i.should eq(3)
  end

  it "codegens if with an else with true" do
    run("a = 1; if true; a = 2; else; a = 3; end; a").to_i.should eq(2)
  end

  it "codegens if inside def without an else with true" do
    run("def foo; a = 1; if true; a = 2; end; a; end; foo").to_i.should eq(2)
  end

  it "codegen if inside if" do
    run("a = 1; if false; a = 1; elsif false; a = 2; else; a = 3; end; a").to_i.should eq(3)
  end

  it "codegens if value from then" do
    run("if true; 1; else 2; end").to_i.should eq(1)
  end

  pending "codegens if with union" do
    program = Program.new
    union = program.run("a = if true; 2.5_f32; else; 1; end; a.ptr").to_pointer
    union.as(Int32).value.should eq(program.float32.type_id)
    (union + 4).as(Float32).value.should eq(2.5)
  end
end
