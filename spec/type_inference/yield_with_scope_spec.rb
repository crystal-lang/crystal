require 'spec_helper'

describe 'Type inference: yield with scope' do
  it "infer type of empty block body" do
    assert_type(%q(
      def foo; 1.yield; end

      foo do
      end
    )) { self.nil }
  end

  it "infer type of block body" do
    input = parse %q(
      def foo; 1.yield; end

      foo do
        x = 1
      end
    )
    mod, input = infer_type input
    input.last.block.body.target.type.should eq(mod.int32)
  end

  it "infer type of block body with yield scope" do
    input = parse %q(
      def foo; 1.yield; end

      foo do
        to_i64
      end
    )
    mod, input = infer_type input
    input.last.block.body.type.should eq(mod.int64)
  end

  it "infer type of block body with yield scope and arguments" do
    input = parse %q(
      def foo; 1.yield 1.5; end

      foo do |f|
        to_i64 + f
      end
    )
    mod, input = infer_type input
    input.last.block.body.type.should eq(mod.float64)
  end
end
