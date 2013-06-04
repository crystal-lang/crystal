require 'spec_helper'

describe 'Type inference: string' do
  it "can call a fun with String for Char*" do
    nodes = parse %q(require "range"; require "string"; lib A; fun a(c : Char*) : Int; end; A.a("x"))
    mod, nodes = infer_type nodes
    nodes.last.args[0].should eq(Call.new(StringLiteral.new("x"), "cstr"))
    nodes.last.type.should eq(mod.int)
  end
end
