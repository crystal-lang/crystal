require "../../spec_helper"

describe "Type inference: union" do
  it "types union when obj is union" do
    assert_type("struct Char; def +(other); self; end; end; a = 1 || 'a'; a + 1") { union_of(int32, char) }
  end

  it "types union when arg is union" do
    assert_type("struct Int; def +(x : Char); x; end; end; a = 1 || 'a'; 1 + a") { union_of(int32, char) }
  end

  it "types union when both obj and arg are union" do
    assert_type("struct Char; def +(other); self; end; end; struct Int; def +(x : Char); x; end; end; a = 1 || 'a'; a + a") { union_of(int32, char) }
  end

  it "types union of classes" do
    assert_type("class A; end; class B; end; a = A.new || B.new; a") { union_of(types["A"], types["B"]) }
  end

  it "assigns to union and keeps new union type in call" do
    assert_type("
      def foo(x)
        while false
          x = 'a'
        end
        x
      end

      foo(1 || false)
      ") { union_of(int32, bool, char) }
  end

  it "looks up type in union type with free var" do
    assert_type("
      class Bar(T)
      end

      def foo(x : T)
        Bar(T).new
      end

      foo(1 || 'a')
    ") do
      (types["Bar"] as GenericClassType).instantiate([union_of(int32, char)] of TypeVar)
    end
  end
end
