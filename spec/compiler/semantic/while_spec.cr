require "../../spec_helper"

describe "Semantic: while" do
  it "types while" do
    assert_type("while 1; 1; end") { nil_type }
  end

  it "types while with break without value" do
    assert_type("while 1; break; end") { nil_type }
  end

  it "types while with break with value" do
    assert_type("while 1; break 'a'; end") { nilable char }
  end

  it "types while with multiple breaks with value" do
    assert_type(%(
      while 1
        break 'a' if 1
        break "", 123 if 1
      end
      )) { nilable union_of(char, tuple_of([string, int32])) }
  end

  it "types endless while with break without value" do
    assert_type("while true; break; end") { nil_type }
  end

  it "types endless while with break with value" do
    assert_type("while true; break 1; end") { int32 }
  end

  it "types endless while with multiple breaks with value" do
    assert_type(%(
      while true
        break 'a' if 1
        break "", 123 if 1
      end
      )) { union_of(char, tuple_of([string, int32])) }
  end

  it "reports break cannot be used outside a while" do
    assert_error "break",
      "invalid break"
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
      "invalid next"
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
      ), inject_primitives: true) { nilable int32 }
  end

  it "marks variable as nil if breaking before assigning to it in an endless loop (2)" do
    assert_type(%(
      while true
        break if 1 == 2
        a = 1
      end
      a
      ), inject_primitives: true) { nilable int32 }
  end

  it "types while with && (#1425)" do
    assert_type(%(
      a = 1
      while a.is_a?(Int32) && (1 == 1)
        a = nil
      end
      a
      ), inject_primitives: true) { nilable int32 }
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
      ), inject_primitives: true) { int32 }
  end

  it "types while with assignment and call" do
    assert_type(%(
      while (a = 1) > 0
        break
      end
      a
      ), inject_primitives: true) { int32 }
  end

  it "doesn't modify var's type before while" do
    assert_type(%(
      x = 'x'
      x.ord
      while 1 == 2
        x = 1
      end
      x
      ), inject_primitives: true) { union_of(int32, char) }
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

  it "restricts type after `while` with `not` and `and` (#4242)" do
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
      ), inject_primitives: true) { nilable int32 }
  end

  it "doesn't use type at end of endless while if variable is reassigned" do
    assert_type(%(
      while true
        a = 1
        if 1 == 1
          break
        end
        a = 'x'
      end
      a
      ), inject_primitives: true) { int32 }
  end

  it "doesn't use type at end of endless while if variable is reassigned (2)" do
    assert_type(%(
      a = ""
      while true
        a = 1
        if 1 == 1
          break
        end
        a = 'x'
      end
      a
      ), inject_primitives: true) { int32 }
  end

  it "doesn't use type at end of endless while if variable is reassigned (3)" do
    assert_type(%(
      a = {1}
      while true
        a = a[0]
        if 1 == 1
          break
        end
        a = {'x'}
      end
      a
      ), inject_primitives: true) { union_of(int32, char) }
  end

  it "uses type at end of endless while if variable is reassigned, but not before first break" do
    assert_type(%(
      while true
        if 1 == 1
          break
        end
        a = 1
        if 1 == 1
          break
        end
        a = 'x'
      end
      a
      ), inject_primitives: true) { nilable union_of(int32, char) }
  end

  it "uses type at end of endless while if variable is reassigned, but not before first break (2)" do
    assert_type(%(
      a = ""
      while true
        if 1 == 1
          break
        end
        a = 1
        if 1 == 1
          break
        end
        a = 'x'
      end
      a
      ), inject_primitives: true) { union_of(int32, char, string) }
  end

  it "rebinds condition variable after while body (#6158)" do
    assert_type(%(
      class Foo
        @parent : self?

        def parent
          @parent
        end
      end

      class Bar
        def initialize(@parent : Foo)
        end

        def parent
          @parent
        end
      end

      a = Foo.new
      b = Bar.new(a)
      while b = b.parent
        break if 1 == 1
      end
      b
      ), inject_primitives: true) { nilable types["Foo"] }
  end

  it "doesn't type var as nilable after break inside rescue" do
    assert_type(%(
      while true
        begin
          foo = 1
          break
        rescue
        end
      end
      foo
      )) { int32 }
  end

  it "types variable as nilable if raise before assign" do
    assert_type(%(
      require "prelude"

      while true
        begin
          raise "oops"
          foo = 12345
        rescue
        end
        break
      end
      foo
      )) { nilable int32 }
  end

  it "finds while cond assign target in Not (#10345)" do
    assert_type(%(
      while !(x = 1 || nil)
      end
      x
      )) { int32 }
  end

  it "finds all while cond assign targets in expressions (#10350)" do
    assert_type(%(
      a = 1
      while ((b = 1); a)
        a = nil
        b = "hello"
      end
      b
      )) { int32 }
  end

  it "finds all while cond assign targets in expressions (2)" do
    assert_type(%(
      def foo(x, y)
        true ? 1 : nil
      end

      while foo(a = 1, b = 1)
        a = nil
        b = "hello"
      end

      {a, b}
      )) { tuple_of [int32, int32] }
  end

  it "finds all while cond assign targets in expressions (3)" do
    assert_type(%(
      while 1 == 1 ? (x = 1; 1 == 1) : false
        x = 'a'
      end
      x
      ), inject_primitives: true) { nilable union_of(int32, char) }
  end

  it "finds all while cond assign targets in expressions (4)" do
    assert_type(%(
      x = ""
      while 1 == 1 ? (x = 1; 1 == 1) : false
        x = 'a'
      end
      x
      ), inject_primitives: true) { union_of(int32, char, string) }
  end

  it "finds all while cond assign targets in expressions (5)" do
    assert_type(%(
      while 1 == 1 ? (x = 1; 1 == 1) : false
        x
        x = 'a'
      end
      x
      ), inject_primitives: true) { nilable union_of(int32, char) }
  end

  it "finds all while cond assign targets in expressions (6)" do
    assert_type(%(
       while (x = true ? (y = 1) : 1; y = x; 1 == 1)
         x = 'a'
       end
       {x, y}
      ), inject_primitives: true) { tuple_of [int32, int32] }
  end

  it "doesn't fail on new variables inside typeof condition" do
    assert_type(%(
      def foo
        while typeof(x = 1)
          return ""
        end
      end

      foo
      )) { nilable string }
  end

  it "doesn't fail on nested conditionals inside typeof condition" do
    assert_type(%(
      def foo
        while typeof(1 || 'a')
          return ""
        end
      end

      foo
      )) { nilable string }
  end

  it "doesn't fail on Expressions condition (1)" do
    assert_type(%(
      def foo
        while (v = 1; true)
          return typeof(v)
        end
        'a'
      end

      foo
      )) { union_of int32.metaclass, char }
  end

  it "doesn't fail on Expressions condition (2)" do
    assert_type(%(
      def foo
        while (v = nil; true)
          return typeof(v)
        end
        'a'
      end

      foo
      )) { union_of nil_type.metaclass, char }
  end
end
