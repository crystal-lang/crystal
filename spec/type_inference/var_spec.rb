require 'spec_helper'

describe 'Type inference: var' do
  it "types an assign" do
    input = Assign.new('a'.var, 1.int)
    mod, input = infer_type input
    input.target.type.should eq(mod.int)
    input.value.type.should eq(mod.int)
    input.type.should eq(mod.int)
  end

  it "types a variable" do
    input = parse 'a = 1; a'
    mod, input = infer_type input

    input.last.type.should eq(mod.int)
    input.type.should eq(mod.int)
  end

  it "types a variable that gets a new type" do
    assert_type('a = 1 || 2.3; a') { union_of(int, double) }
  end

  it "reports undefined local variable or method" do
    assert_error %(
      def foo
        a = something
      end

      def bar
        foo
      end

      bar),
      "undefined local variable or method 'something'"
  end

  it "reports read before assignment" do
    assert_syntax_error "a += 1",
      "'+=' before definition of 'a'"
  end

  it "reports read before assignment" do
    assert_error "a = a + 1",
      "undefined local variable or method 'a'"
  end
end