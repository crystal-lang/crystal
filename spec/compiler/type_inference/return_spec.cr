require "../../spec_helper"

describe "Type inference: return" do
  it "infers return type" do
    assert_type("def foo; return 1; end; foo") { int32 }
  end

  it "infers return type with many returns (1)" do
    assert_type("def foo; if true; return 1; end; 'a'; end; foo") { int32 }
  end

  it "infers return type with many returns (2)" do
    assert_type("def foo; if 1 == 1; return 1; end; 'a'; end; foo") { union_of(int32, char) }
  end

  it "errors on return in top level" do
    assert_error "return",
      "can't return from top level"
  end

  it "types return if true" do
    assert_type(%(
      def bar
        return if true
        1
      end

      bar
      )) { |mod| mod.nil }
  end
end
