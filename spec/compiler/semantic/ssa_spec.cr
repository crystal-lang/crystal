require "../../spec_helper"

include Crystal

describe "Semantic: ssa" do
  it "types a redefined variable" do
    assert_type(<<-CRYSTAL) { char }
      a = 1
      a = 'a'
      a
      CRYSTAL
  end

  it "types a var inside an if without previous definition" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      if 1 == 1
        a = 1
      else
        a = 'a'
      end
      a
      CRYSTAL
  end

  it "types a var inside an if with previous definition" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = "hello"
      if 1 == 1
        a = 1
      else
        a = 'a'
      end
      a
      CRYSTAL
  end

  it "types a var inside an if without change in then" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = 1
      if 1 == 1
      else
        a = 'a'
      end
      a
      CRYSTAL
  end

  it "types a var inside an if without change in else" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = 1
      if 1 == 1
        a = 'a'
      else
      end
      a
      CRYSTAL
  end

  it "types a var inside an if without definition in else" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable char }
      if 1 == 1
        a = 'a'
      else
      end
      a
      CRYSTAL
  end

  it "types a var inside an if without definition in then" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable char }
      if 1 == 1
      else
        a = 'a'
      end
      a
      CRYSTAL
  end

  it "types a var with an if but without change" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = 1
      if 1 == 1
      else
      end
      a
      CRYSTAL
  end

  it "types a var with an if with nested if" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      if 1 == 2
        a = 1
      else
        if 2 == 3
        end
        a = 4
      end
      a
      CRYSTAL
  end

  it "types a var that is re-assigned in a block" do
    assert_type(<<-CRYSTAL) { union_of(int32, char) }
      def foo
        yield
      end

      a = 1
      foo do
        a = 'a'
      end
      a
      CRYSTAL
  end

  it "types a var that is re-assigned in a while" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = 1
      while 1 == 2
        a = 'a'
      end
      a
      CRYSTAL
  end

  it "types a var that is re-assigned in a while and used in condition" do
    assert_type(<<-CRYSTAL) { union_of(int32, char) }
      a = 1
      while b = a
        a = 'a'
      end
      b
      CRYSTAL
  end

  it "types a var that is re-assigned in a while in next and used in condition" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = 1
      while b = a
        if 1 == 1
          a = 'a'
          next
        end
        a = 1
      end
      b
      CRYSTAL
  end

  it "types a var that is declared in a while" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable int32 }
      while 1 == 2
        a = 1
      end
      a
      CRYSTAL
  end

  it "types a var that is re-assigned in a while condition" do
    assert_type(<<-CRYSTAL) { char }
      a = 1
      while a = 'a'
        a = "hello"
      end
      a
      CRYSTAL
  end

  it "types a var that is declared in a while condition" do
    assert_type(<<-CRYSTAL) { char }
      while a = 'a'
        a = "hello"
      end
      a
      CRYSTAL
  end

  it "types a var that is declared in a while with out" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(char, int32) }
      lib LibC
        fun foo(x : Int32*)
      end

      a = 'a'
      while 1 == 2
        LibC.foo(out x)
        a = x
      end
      a
      CRYSTAL
  end

  it "types a var after begin ensure as having last type" do
    assert_type(<<-CRYSTAL) { string }
      a = 1.5
      begin
        a = 2
        a = 'a'
        a = "hello"
      ensure
      end
      a
      CRYSTAL
  end

  it "types a var after begin ensure as having last type (2)" do
    assert_type(<<-CRYSTAL) { char }
      begin
        a = 2
        a = 'a'
      ensure
      end
      a
      CRYSTAL
  end

  it "doesn't change type to nilable inside if" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        yield
      end

      def bar
        if 1 == 2
          l = 1
          foo {}
          l
        else
          2
        end
      end

      x = bar
      CRYSTAL
  end

  it "types if with return in then" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        if 1 == 1
          a = 1
        else
          return 2
        end
        a
      end

      foo
      CRYSTAL
  end

  it "types if with return in then with assign" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        if 1 == 1
          a = 1
        else
          a = 'a'
          return 2
        end
        a
      end

      foo
      CRYSTAL
  end

  it "types if with return in else" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        if 1 == 1
          return 2
        else
          a = 1
        end
        a
      end

      foo
      CRYSTAL
  end

  it "types if with return in else with assign" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        if 1 == 1
          a = 'a'
          return 2
        else
          a = 1
        end
        a
      end

      foo
      CRYSTAL
  end

  it "types if with return in both branches" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        if 1 == 1
          if 2 == 2
            a = 'a'
            return 2
          else
            a = false
            return 3
          end
        else
          a = 1
        end
        a
      end

      foo
      CRYSTAL
  end

  it "types if with unreachable in then" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      lib LibC
        fun exit : NoReturn
      end

      if 1 == 1
        a = 1
      else
        a = 'a'
        LibC.exit
      end

      a
      CRYSTAL
  end

  it "types if with break in then" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      b = 1

      while 1 == 2
        if 1 == 1
          a = 1
        else
          a = 'a'
          break
        end
        b = a
      end

      b
      CRYSTAL
  end

  it "types if with next in then" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      b = 1

      while 1 == 2
        if 1 == 1
          a = 1
        else
          a = 'a'
          next
        end
        b = a
      end

      b
      CRYSTAL
  end

  it "types while with break" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = 1

      while 1 == 2
        if 1 == 1
          a = 'a'
          break
        end
        a = 1
      end

      a
      CRYSTAL
  end

  it "types while with break with new var" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable char }
      while 1 == 2
        if 1 == 1
          b = 'a'
          break
        end
      end

      b
      CRYSTAL
  end

  it "types while with break doesn't infect initial vars" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = 1
      b = 1

      while 1 == 2
        b = a
        if 1 == 1
          a = 'a'
          break
        end
        a = 1
      end

      b
      CRYSTAL
  end

  it "types a var that is declared in a while condition with break before re-assignment" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { char }
      while a = 'a'
        break if 1 == 1
        a = "hello"
      end
      a
      CRYSTAL
  end

  it "types a var that is declared in a while condition with break after re-assignment" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(char, string) }
      while a = 'a'
        a = "hello"
        break if 1 == 1
      end
      a
      CRYSTAL
  end

  it "types while with next" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      a = 1
      b = 1
      while 1 == 2
        b = a
        if 1 == 1
          a = 'a'
          next
        end
        a = 1
      end

      b
      CRYSTAL
  end

  it "types block with break" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      def foo
        yield
      end

      a = 1

      foo do
        if 1 == 1
          a = 'a'
          break
        end
        a = 1
      end

      a
      CRYSTAL
  end

  it "types block with break doesn't infect initial vars" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        yield
      end

      a = 1
      b = 1

      foo do
        b = a
        if 1 == 1
          a = 'a'
          break
        end
        a = 1
      end

      b
      CRYSTAL
  end

  it "types block with next" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
      def foo
        yield
      end

      a = 1
      b = 1

      foo do
        b = a
        if 1 == 1
          a = 'a'
          next
        end
        a = 1
      end

      b
      CRYSTAL
  end

  it "types if with restricted type in then" do
    assert_type(<<-CRYSTAL) { char }
      a = 1 || 'a'
      if a.is_a?(Int32)
        a = 'a'
      else
        # a = 'a'
      end
      a
      CRYSTAL
  end

  it "types if with restricted type in else" do
    assert_type(<<-CRYSTAL) { int32 }
      a = 1 || 'a'
      if a.is_a?(Int32)
        # a = 1
      else
        a = 1
      end
      a
      CRYSTAL
  end

  it "types if/else with var (bug)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable int32 }
      a = 1 || nil
      d = nil
      if a && 1 == 2
        b = 2
      else
        d = a
      end
      d
      CRYSTAL
  end

  it "types re-assign inside if (bug)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable int32 }
      struct Nil
        def to_i
          0
        end
      end

      index = nil
      if index
        a = index
      else
        if 1 == 1
          index = 1
        end
        a = index
      end
      a
      CRYSTAL
  end

  it "types re-assign inside while (bug)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable int32 }
      struct Nil
        def to_i
          0
        end
      end

      index = nil
      if index
        a = index
      else
        while 1 == 2
          index = 1
        end
        a = index
      end
      a
      CRYSTAL
  end

  it "preserves type filters after block (bug)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        yield
      end

      if (a = 'a' || nil) && (b = 2)
        if 1 == 2
          foo { }
        end
        a.ord
      else
        1
      end
      CRYSTAL
  end

  it "errors if accessing variable declared inside typeof" do
    assert_error %(
      typeof(x = 1)
      x
      ),
      "undefined local variable or method 'x'"
  end

  it "doesn't error if same variable is declared in multiple typeofs" do
    assert_type(<<-CRYSTAL) { char.metaclass }
      typeof((x = uninitialized Int32; x))
      typeof((x = uninitialized Char; x))
      CRYSTAL
  end

  it "doesn't error if same variable is used in multiple arguments of same typeof" do
    assert_type(<<-CRYSTAL) { union_of(string, char).metaclass }
      def foo(x : String)
        'a'
      end

      x = 1
      typeof(x = "", x = foo(x))
      CRYSTAL
  end
end
