require "../../spec_helper"

describe "Normalize: proc pointer" do
  it "normalizes proc pointer to proc literal (->foo)" do
    assert_expand %(->foo), %(-> do\n  foo\nend)
  end

  it "normalizes proc pointer to proc literal (->var.foo)" do
    assert_expand_second %(var = 1; ->var.foo), %(-> do\n  var.foo\nend)
  end

  it "normalizes proc pointer to proc literal (->@ivar.foo)" do
    assert_expand %(->@ivar.foo), %(-> do\n  @ivar.foo\nend)
  end

  it "normalizes proc pointer to proc literal (->Foo.foo)" do
    assert_expand %(->Foo.foo), %(-> do\n  Foo.foo\nend)
  end

  it "normalizes proc pointer to proc literal (->foo(Type))" do
    assert_expand %(->foo(Type)), %(->(__temp_1 : Type) do\n  foo(__temp_1)\nend)
  end
end
