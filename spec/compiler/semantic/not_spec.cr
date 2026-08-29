require "../../spec_helper"

describe "Semantic: not" do
  it "types not" do
    assert_type(<<-CRYSTAL) { bool }
      !1
      CRYSTAL
  end

  it "types not as NoReturn if exp is NoReturn" do
    assert_type(<<-CRYSTAL) { no_return }
      lib LibC
        fun exit : NoReturn
      end

      !LibC.exit
      CRYSTAL
  end

  it "filters types inside if" do
    assert_type(<<-CRYSTAL) { nil_type }
      a = 1 || nil
      z = nil
      if !a
        z = a
      end
      z
      CRYSTAL
  end

  it "filters types inside if/else" do
    assert_type(<<-CRYSTAL) { int32 }
      a = 1 || nil
      z = 2
      if !a
      else
        z = a
      end
      z
      CRYSTAL
  end

  it "filters types with !is_a?" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = 1 == 2 ? "x" : 1
      z = 0
      if !a.is_a?(String)
        z = a + 10
      end
      z
      CRYSTAL
  end

  it "doesn't restrict and" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable int32 }
      a = 1 || nil
      z = nil
      if !(a && (1 == 2))
        z = a
      end
      z
      CRYSTAL
  end

  it "doesn't restrict and in while (#4243)" do
    assert_type(<<-CRYSTAL) { nilable int32 }
      x = nil
      y = nil
      z = nil

      while !(x && y)
        z = x
        x = 1
      end

      z
      CRYSTAL
  end
end
