require 'spec_helper'

describe 'Type inference: struct' do
  it "types struct" do
    input = parse "lib Foo; struct Bar; x : Int; y : Float; end; end; Foo::Bar"
    mod = infer_type input
    mod.types['Foo'].types['Bar'].should eq(StructType.new('Bar', [Var.new('x', mod.int), Var.new('y', mod.float)]))
  end
end
