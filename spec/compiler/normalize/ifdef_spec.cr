require "../../spec_helper"

describe "Normalize: ifdef" do
  it "keeps then if condition is true" do
    assert_normalize "ifdef foo; 1; else; 2; end", "1", flags: "foo"
  end

  it "keeps else if condition is false" do
    assert_normalize "ifdef bar; 1; else; 2; end", "2", flags: "foo"
  end

  it "keeps then if condition is true inside lib" do
    assert_normalize "lib Foo; ifdef foo; type A = B; else; type A = D; end; end", "lib Foo\n  type A : B\nend", flags: "foo"
  end
end
