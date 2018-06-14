require "../../spec_helper"

describe "Semantic: overflow check scope" do
  it "type block by expression" do
    assert_type("checked { 1 }") { int32 }
    assert_type("unchecked { 1 }") { int32 }
    assert_type("checked { 1 + 2; '1' }") { char }
    assert_type("def foo; unchecked { return 1 }; end; foo") { int32 }
  end
end
