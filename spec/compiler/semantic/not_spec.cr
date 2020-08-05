require "../../spec_helper"

describe "Semantic: not" do
  it "types not" do
    assert_type(%(
      !1
      )) { bool }
  end

  it "types not as NoReturn if exp is NoReturn" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      !LibC.exit
      )) { no_return }
  end

  it "filters types inside if" do
    assert_type(%(
      a = 1 || nil
      z = nil
      if !a
        z = a
      end
      z
      )) { nil_type }
  end

  it "filters types inside if/else" do
    assert_type(%(
      a = 1 || nil
      z = 2
      if !a
      else
        z = a
      end
      z
      )) { int32 }
  end

  it "filters types with !is_a?" do
    assert_type(%(
      a = 1 == 2 ? "x" : 1
      z = 0
      if !a.is_a?(String)
        z = a + 10
      end
      z
      )) { int32 }
  end

  it "doesn't restrict and" do
    assert_type(%(
      a = 1 || nil
      z = nil
      if !(a && (1 == 2))
        z = a
      end
      z
      )) { nilable int32 }
  end

  it "doesn't restrict and in while (#4243)" do
    assert_type(%(
      x = nil
      y = nil
      z = nil

      while !(x && y)
        z = x
        x = 1
      end

      z
      )) { nilable int32 }
  end
end
