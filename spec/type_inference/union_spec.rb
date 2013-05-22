require 'spec_helper'

describe "Type inference: union" do
  it "types union when obj is union" do
    assert_type("a = 1; a = 2.3; a + 1") { union_of(int, double) }
  end

  it "types union when arg is union" do
    assert_type("a = 1; a = 2.3; 1 + a") { union_of(int, double) }
  end

  it "types union when both obj and arg are union" do
    assert_type("a = 1; a = 2.3; a + a") { union_of(int, double) }
  end

  it "types union of classes" do
    assert_type("class A; end; class B; end; a = A.new; a = B.new; a") { union_of(types["A"], types["B"]) }
  end
end