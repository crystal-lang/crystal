require "../../spec_helper"

describe "Semantic: while" do
  it "types while" do
    assert_type("while 1; 1; end") { nil_type }
  end

  it "types while with break without value" do
    assert_type("while true; break; end") { nil_type }
  end

  it "types while with break with value" do
    assert_type("while true; break 1; end") { nil_type }
  end

  it "reports break cannot be used outside a while" do
    assert_error "break",
      "Invalid break"
  end

  it "types while true as NoReturn" do
    assert_type("while true; end") { no_return }
  end

  it "types while (true) as NoReturn" do
    assert_type("while (true); end") { no_return }
  end

  it "types while ((true)) as NoReturn" do
    assert_type("while ((true)); end") { no_return }
  end

  it "reports next cannot be used outside a while" do
    assert_error "next",
      "Invalid next"
  end

  it "uses var type inside while if endless loop" do
    assert_type(%(
      a = nil
      while true
        a = 1
        break
      end
      a
      )) { int32 }
  end

  it "uses var type inside while if endless loop (2)" do
    assert_type(%(
      while true
        a = 1
        break
      end
      a
      )) { int32 }
  end

  it "marks variable as nil if breaking before assigning to it in an endless loop" do
    assert_type(%(
      a = nil
      while true
        break if 1 == 2
        a = 1
      end
      a
      )) { nilable int32 }
  end

  it "marks variable as nil if breaking before assigning to it in an endless loop (2)" do
    assert_type(%(
      while true
        break if 1 == 2
        a = 1
      end
      a
      )) { nilable int32 }
  end

  it "types while with && (#1425)" do
    assert_type(%(
      a = 1
      while a.is_a?(Int32) && (1 == 1)
        a = nil
      end
      a
      )) { nilable int32 }
  end

  it "types while with assignment" do
    assert_type(%(
      while a = 1
        break
      end
      a
      )) { int32 }
  end

  it "types while with assignment and &&" do
    assert_type(%(
      while (a = 1) && (1 == 1)
        break
      end
      a
      )) { int32 }
  end

  it "types while with assignment and call" do
    assert_type(%(
      while (a = 1) > 0
        break
      end
      a
      )) { int32 }
  end

  it "doesn't modify var's type before while" do
    assert_type(%(
      x = 'x'
      x.ord
      while 1 == 2
        x = 1
      end
      x
      )) { union_of(int32, char) }
  end

  it "restricts type after while (#4242)" do
    assert_type(%(
      a = nil
      while a.nil?
        a = 1
      end
      a
      )) { int32 }
  end

  it "restricts type after while with not (#4242)" do
    assert_type(%(
      a = nil
      while !a
        a = 1
      end
      a
      )) { int32 }
  end

  it "restricts type after while with not and and (#4242)" do
    assert_type(%(
      a = nil
      b = nil
      while !(a && b)
        a = 1
        b = 'a'
      end
      {a, b}
      )) { tuple_of [int32, char] }
  end

  it "doesn't restrict type after while if there's a break (#4242)" do
    assert_type(%(
      a = nil
      while a.nil?
        if 1 == 1
          break
        end
        a = 1
      end
      a
      )) { nilable int32 }
  end
end
