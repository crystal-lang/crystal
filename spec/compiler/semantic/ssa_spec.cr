require "../../spec_helper"

include Crystal

describe "Semantic: ssa" do
  it "types a redefined variable" do
    assert_type("
      a = 1
      a = 'a'
      a
      ") { char }
  end

  it "types a var inside an if without previous definition" do
    assert_type("
      if 1 == 1
        a = 1
      else
        a = 'a'
      end
      a
      ") { union_of(int32, char) }
  end

  it "types a var inside an if with previous definition" do
    assert_type(%(
      a = "hello"
      if 1 == 1
        a = 1
      else
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var inside an if without change in then" do
    assert_type(%(
      a = 1
      if 1 == 1
      else
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var inside an if without change in else" do
    assert_type(%(
      a = 1
      if 1 == 1
        a = 'a'
      else
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var inside an if without definition in else" do
    assert_type(%(
      if 1 == 1
        a = 'a'
      else
      end
      a
      )) { nilable char }
  end

  it "types a var inside an if without definition in then" do
    assert_type(%(
      if 1 == 1
      else
        a = 'a'
      end
      a
      )) { nilable char }
  end

  it "types a var with an if but without change" do
    assert_type(%(
      a = 1
      if 1 == 1
      else
      end
      a
      )) { int32 }
  end

  it "types a var with an if with nested if" do
    assert_type(%(
      if 1 == 2
        a = 1
      else
        if 2 == 3
        end
        a = 4
      end
      a
      )) { int32 }
  end

  it "types a var that is re-assigned in a block" do
    assert_type(%(
      def foo
        yield
      end

      a = 1
      foo do
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var that is re-assigned in a while" do
    assert_type(%(
      a = 1
      while 1 == 2
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var that is re-assigned in a while and used in condition" do
    assert_type(%(
      a = 1
      while b = a
        a = 'a'
      end
      b
      )) { union_of(int32, char) }
  end

  it "types a var that is re-assigned in a while in next and used in condition" do
    assert_type(%(
      a = 1
      while b = a
        if 1 == 1
          a = 'a'
          next
        end
        a = 1
      end
      b
      )) { union_of(int32, char) }
  end

  it "types a var that is declared in a while" do
    assert_type(%(
      while 1 == 2
        a = 1
      end
      a
      )) { nilable int32 }
  end

  it "types a var that is re-assigned in a while condition" do
    assert_type(%(
      a = 1
      while a = 'a'
        a = "hello"
      end
      a
      )) { char }
  end

  it "types a var that is declared in a while condition" do
    assert_type(%(
      while a = 'a'
        a = "hello"
      end
      a
      )) { char }
  end

  it "types a var that is declared in a while with out" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32*)
      end

      a = 'a'
      while 1 == 2
        LibC.foo(out x)
        a = x
      end
      a
      )) { union_of(char, int32) }
  end

  it "types a var after begin ensure as having last type" do
    assert_type(%(
      a = 1.5
      begin
        a = 2
        a = 'a'
        a = "hello"
      ensure
      end
      a
      )) { string }
  end

  it "types a var after begin ensure as having last type (2)" do
    assert_type(%(
      begin
        a = 2
        a = 'a'
      ensure
      end
      a
      )) { char }
  end

  it "types a var after begin rescue as having all possible types and nil in begin if read (2)" do
    assert_type(%(
      begin
        a = 2
        a = 'a'
      rescue
      end
      a
      )) { union_of [int32, char, nil_type] of Type }
  end

  it "types a var after begin rescue as having all possible types in begin and rescue" do
    assert_type(%(
      a = 1.5
      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        a = false
      end
      a
      )) { union_of [float64, int32, char, string, bool] of Type }
  end

  it "types a var after begin rescue as having all possible types in begin and rescue (2)" do
    assert_type(%(
      b = 2
      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        b = a
      end
      b
      )) { union_of [int32, char, string, nil_type] of Type }
  end

  it "types a var after begin rescue with no-return in rescue" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        LibC.exit
      end
      a
      )) { string }
  end

  it "types a var after rescue as being nilable" do
    assert_type(%(
      begin
      rescue
        a = 1
      end
      a
      )) { nilable int32 }
  end

  it "doesn't change type to nilable inside if" do
    assert_type("
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
      ") { int32 }
  end

  it "types if with return in then" do
    assert_type("
      def foo
        if 1 == 1
          a = 1
        else
          return 2
        end
        a
      end

      foo
      ") { int32 }
  end

  it "types if with return in then with assign" do
    assert_type("
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
      ") { int32 }
  end

  it "types if with return in else" do
    assert_type("
      def foo
        if 1 == 1
          return 2
        else
          a = 1
        end
        a
      end

      foo
      ") { int32 }
  end

  it "types if with return in else with assign" do
    assert_type("
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
      ") { int32 }
  end

  it "types if with return in both branches" do
    assert_type("
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
      ") { int32 }
  end

  it "types if with unreachable in then" do
    assert_type("
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
      ") { int32 }
  end

  it "types if with break in then" do
    assert_type("
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
      ") { int32 }
  end

  it "types if with next in then" do
    assert_type("
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
      ") { int32 }
  end

  it "types while with break" do
    assert_type("
      a = 1

      while 1 == 2
        if 1 == 1
          a = 'a'
          break
        end
        a = 1
      end

      a
      ") { union_of(int32, char) }
  end

  it "types while with break with new var" do
    assert_type("
      while 1 == 2
        if 1 == 1
          b = 'a'
          break
        end
      end

      b
      ") { nilable char }
  end

  it "types while with break doesn't infect initial vars" do
    assert_type("
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
      ") { int32 }
  end

  it "types while with next" do
    assert_type("
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
      ") { union_of(int32, char) }
  end

  it "types block with break" do
    assert_type("
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
      ") { union_of(int32, char) }
  end

  it "types block with break doesn't infect initial vars" do
    assert_type("
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
      ") { int32 }
  end

  it "types block with next" do
    assert_type("
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
      ") { union_of(int32, char) }
  end

  it "types if with restricted type in then" do
    assert_type("
      a = 1 || 'a'
      if a.is_a?(Int32)
        a = 'a'
      else
        # a = 'a'
      end
      a
      ") { char }
  end

  it "types if with restricted type in else" do
    assert_type("
      a = 1 || 'a'
      if a.is_a?(Int32)
        # a = 1
      else
        a = 1
      end
      a
      ") { int32 }
  end

  it "types if/else with var (bug)" do
    assert_type("
      a = 1 || nil
      d = nil
      if a && 1 == 2
        b = 2
      else
        d = a
      end
      d
      ") { nilable int32 }
  end

  it "types re-assign inside if (bug)" do
    assert_type("
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
      ") { nilable int32 }
  end

  it "types re-assign inside while (bug)" do
    assert_type("
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
      ") { nilable int32 }
  end

  it "preserves type filters after block (bug)" do
    assert_type("
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
      ") { int32 }
  end
end
