require "../../spec_helper"

describe "Global inference" do
  it "infers type of global assign" do
    node = parse "$foo = 1"
    result = semantic node
    mod, node = result.program, result.node.as(Assign)

    node.type.should eq(mod.int32)
    node.target.type.should eq(mod.int32)
    node.value.type.should eq(mod.int32)
  end

  it "infers type of global assign with union" do
    nodes = parse "$foo = 1; $foo = 'a'"
    result = semantic nodes
    mod, node = result.program, result.node.as(Expressions)

    node[0].as(Assign).target.type.should eq(mod.union_of(mod.int32, mod.char))
    node[1].as(Assign).target.type.should eq(mod.union_of(mod.int32, mod.char))
  end

  it "errors when reading undefined global variables" do
    assert_error %(
      $x
      ), "Can't infer the type of global variable '$x'"
  end

  it "errors when writing undefined global variables" do
    assert_error %(
      def foo
        1
      end

      $x = foo
      ), "Can't infer the type of global variable '$x'"
  end

  it "infers type from number literal" do
    assert_type(%(
      $x = 1
      $x
      )) { int32 }
  end

  it "infers type from char literal" do
    assert_type(%(
      $x = 'a'
      $x
      )) { char }
  end

  it "infers type from bool literal" do
    assert_type(%(
      $x = true
      $x
      )) { bool }
  end

  it "infers type from nil literal" do
    assert_type(%(
      $x = nil
      $x
      )) { nil_type }
  end

  it "infers type from string literal" do
    assert_type(%(
      $x = "foo"
      $x
      )) { string }
  end

  it "infers type from string interpolation" do
    assert_type(%(
      require "prelude"

      $x = "foo\#{1}"
      $x
      )) { string }
  end

  it "infers type from symbol literal" do
    assert_type(%(
      $x = :foo
      $x
      )) { symbol }
  end

  it "infers type from array literal with of" do
    assert_type(%(
      $x = [] of Int32
      $x
      )) { array_of int32 }
  end

  it "infers type from array literal with of (metaclass)" do
    assert_type(%(
      $x = [] of Int32.class
      $x
      )) { array_of int32.metaclass }
  end

  it "infers type from array literal with of, inside another type" do
    assert_type(%(
      class Foo
        class Bar
        end

        $x = [] of Bar
      end

      $x
      )) { array_of types["Foo"].types["Bar"] }
  end

  it "infers type from array literal from its literals" do
    assert_type(%(
      require "prelude"

      $x = [1, 'a']
      $x
      )) { array_of union_of(int32, char) }
  end

  it "infers type from hash literal with of" do
    assert_type(%(
      require "prelude"

      $x = {} of Int32 => String
      $x
      )) { hash_of(int32, string) }
  end

  it "infers type from hash literal from elements" do
    assert_type(%(
      require "prelude"

      $x = {1 => "foo", 'a' => true}
      $x
      )) { hash_of(union_of(int32, char), union_of(string, bool)) }
  end

  it "infers type from range literal" do
    assert_type(%(
      require "prelude"

      $x = 1..'a'
      $x
      )) { range_of(int32, char) }
  end

  it "infers type from regex literal" do
    assert_type(%(
      require "prelude"

      $x = /foo/
      $x
      )) { types["Regex"] }
  end

  it "infers type from regex literal with interpolation" do
    assert_type(%(
      require "prelude"

      $x = /foo\#{1}/
      $x
      )) { types["Regex"] }
  end

  it "infers type from tuple literal" do
    assert_type(%(
      $x = {1, "foo"}
      $x
      )) { tuple_of([int32, string]) }
  end

  it "infers type from named tuple literal" do
    assert_type(%(
      $x = {x: 1, y: "foo"}
      $x
      )) { named_tuple_of({"x": int32, "y": string}) }
  end

  it "infers type from new expression" do
    assert_type(%(
      class Foo
      end

      $x = Foo.new
      $x
      )) { types["Foo"] }
  end

  it "doesn't infer from new if generic" do
    assert_error %(
      class Foo(T)
        def self.new
          a = 10
          a
        end
      end

      $x = Foo.new
      $x
      ),
      "can't use Foo(T) as the type of global variable $x, use a more specific type"
  end

  it "infers type from new expression of generic" do
    assert_type(%(
      class Foo(T)
      end

      $x = Foo(Int32).new
      $x
      )) { generic_class "Foo", int32 }
  end

  it "infers type from as" do
    assert_type(%(
      def foo
        1
      end

      $x = foo as Int32
      $x
      )) { int32 }
  end

  it "infers type from as?" do
    assert_type(%(
      def foo
        1
      end

      $x = foo.as?(Int32)
      $x
      )) { nilable int32 }
  end

  it "infers type from static array type declaration" do
    assert_type(%(
      $x : Int8[3]?
      $x
      )) { nilable static_array_of(int8, 3) }
  end

  it "infers type from argument restriction" do
    assert_type(%(
      class Foo
        class Bar
        end

        def foo(z : Bar)
          $x = z
        end
      end

      $x
      )) { nilable types["Foo"].types["Bar"] }
  end

  it "infers type from argument default value" do
    assert_type(%(
      class Foo
        class Bar
        end

        def foo(z = Foo::Bar.new)
          $x = z
        end
      end

      $x
      )) { nilable types["Foo"].types["Bar"] }
  end

  it "infers type from lib fun call" do
    assert_type(%(
      lib LibFoo
        struct Bar
          x : Int32
        end

        fun foo : Bar
      end

      $x = LibFoo.foo
      )) { types["LibFoo"].types["Bar"] }
  end

  it "infers type from lib variable" do
    assert_type(%(
      lib LibFoo
        struct Bar
          x : Int32
        end

        $foo : Bar
      end

      $x = LibFoo.foo
      )) { types["LibFoo"].types["Bar"] }
  end

  it "infers from ||" do
    assert_type(%(
      $x = 1 || true
      )) { union_of(int32, bool) }
  end

  it "infers from &&" do
    assert_type(%(
      $x = 1 && true
      )) { union_of(int32, bool) }
  end

  it "infers from ||=" do
    assert_type(%(
      def foo
        $x ||= 1
      end

      $x
      )) { nilable int32 }
  end

  it "infers from ||= inside another assignment" do
    assert_type(%(
      def foo
        x = $x ||= 1
      end

      $x
      )) { nilable int32 }
  end

  it "infers from if" do
    assert_type(%(
      $x = 1 == 2 ? 1 : true
      )) { union_of(int32, bool) }
  end

  it "infers from case" do
    assert_type(%(
      class Object
        def ===(other)
          self == other
        end
      end

      $x = case 1
           when 2
             'a'
           else
             true
           end
      )) { union_of(char, bool) }
  end

  it "infers from unless" do
    assert_type(%(
      $x = unless 1 == 2
             1
           else
             true
           end
      )) { union_of(int32, bool) }
  end

  it "infers from begin" do
    assert_type(%(
      $x = begin
        1
        'a'
      end
      )) { char }
  end

  it "infers from assign (1)" do
    assert_type(%(
      $x = $y = 1
      $x
      )) { int32 }
  end

  it "infers from assign (2)" do
    assert_type(%(
      $x = $y = 1
      $y
      )) { int32 }
  end

  it "infers from new at top level" do
    assert_type(%(
      class Foo
        $x = new
      end
      $x
      )) { types["Foo"] }
  end

  it "infers from block argument" do
    assert_type(%(
      def foo(&block : Int32 -> Int32)
        $x = block
      end

      $x
      )) { nilable proc_of(int32, int32) }
  end

  it "infers from block argument without restriction" do
    assert_type(%(
      def foo(&block)
        $x = block
      end

      $x
      )) { nilable proc_of(void) }
  end

  it "infers type from !" do
    assert_type(%(
      $x = !1
      $x
      )) { bool }
  end

  it "infers type from is_a?" do
    assert_type(%(
      $x = 1.is_a?(Int32)
      $x
      )) { bool }
  end

  it "infers type from responds_to?" do
    assert_type(%(
      $x = 1.responds_to?(:foo)
      $x
      )) { bool }
  end

  it "infers type from sizeof" do
    assert_type(%(
      $x = sizeof(Float64)
      $x
      )) { int32 }
  end

  it "infers type from sizeof" do
    assert_type(%(
      class Foo
      end

      $x = instance_sizeof(Foo)
      $x
      )) { int32 }
  end

  it "infers type from path that is a type" do
    assert_type(%(
      class Foo; end
      class Bar < Foo; end

      $x = Foo
      $x
      )) { types["Foo"].virtual_type!.metaclass }
  end

  it "infers type from path that is a constant" do
    assert_type(%(
      CONST = 1

      $x = CONST
      $x
      )) { int32 }
  end

  it "doesn't infer from redefined method" do
    assert_type(%(
      def foo
        $x = 1
      end

      def foo
        $x = true
      end

      $x
      )) { nilable bool }
  end

  it "infers from redefined method if calls previous_def" do
    assert_type(%(
      def foo
        $x = 1
      end

      def foo
        previous_def
      end

      $x
      )) { nilable int32 }
  end

  it "infers type in multi assign (1)" do
    assert_type(%(
      $x, $y = 1, "foo"
      $x
      )) { int32 }
  end

  it "infers type in multi assign (2)" do
    assert_type(%(
      $x, $y = 1, "foo"
      $y
      )) { string }
  end

  it "infers type from enum member" do
    assert_type(%(
      enum Color
        Red, Green, Blue
      end

      $x = Color::Red
      $x
      )) { types["Color"] }
  end

  it "errors if using typeof in type declaration" do
    assert_error %(
      $x : typeof(1)
      $x
      ),
      "can't use 'typeof' here"
  end

  it "doesn't error if using typeof for guessed variable (but doesn't guess)" do
    assert_type(%(
      class Foo(T)
      end

      def foo
        1
      end

      $x = Foo(Int32).new
      $x = Foo(typeof(foo)).new
      $x
      )) { generic_class "Foo", int32 }
  end

  it "infers type of global reference" do
    assert_type("$foo = 1; def foo; $foo = 'a'; end; foo; $foo") { union_of(int32, char) }
  end

  it "infers type of write global variable when not previously assigned" do
    assert_type("def foo; $foo = 1; end; foo; $foo") { nilable int32 }
  end

  it "types constant depending on global (related to #708)" do
    assert_type(%(
      A = foo

      def foo
        if a = $foo
          a
        else
          $foo = 1
        end
      end

      A
      )) { int32 }
  end

  it "declares global variable" do
    assert_error %(
      $x : Int32
      $x = true
      ),
      "global variable '$x' must be Int32, not Bool"
  end

  it "declares global variable as metaclass" do
    assert_type(%(
      $x : Int32.class
      $x = Int32
      $x
      )) { int32.metaclass }
  end

  it "declares global variable and reads it (nilable)" do
    assert_error %(
      $x : Int32
      $x
      ),
      "global variable '$x' is read here before it was initialized, rendering it nilable, but its type is Int32"
  end

  it "declares global variable and reads it inside method" do
    assert_error %(
      $x : Int32

      def foo
        $x = 1
      end

      if 1 == 2
        foo
      end

      $x
      ),
      "global variable '$x' must be Int32, not Nil"
  end

  it "redefines global variable type" do
    assert_type(%(
      $x : Int32
      $x : Int32 | Float64
      $x = 1
      $x
      )) { union_of int32, float64 }
  end

  it "errors when typing a global variable inside a method" do
    assert_error %(
      def foo
        $x : Int32
      end

      foo
      ),
      "declaring the type of a global variable must be done at the class level"
  end

  it "errors on undefined constant" do
    assert_error %(
      $x = Bar.new
      ),
      "undefined constant Bar"
  end

  it "infers in multiple assign for tuple type (1)" do
    assert_type(%(
      class Bar
        def self.method : {Int32, Bool}
          {1, true}
        end
      end

      $x, $y = Bar.method
      $x
      )) { int32 }
  end

  it "expands global var with declaration (#2564)" do
    assert_type(%(
      $x : Bool = 1 <= 2 <= 3
      $x
      )) { bool }
  end

  it "errors when using Class (#2605)" do
    assert_error %(
      class Foo
        def foo(klass : Class)
          $class = klass
        end
      end
      ),
      "can't use Class as the type of global variable $class, use a more specific type"
  end

  it "gives correct error when trying to use Int as a global variable type" do
    assert_error %(
      $x : Int
      ),
      "can't use Int as the type of a global variable yet, use a more specific type"
  end

  it "declares uninitialized (#2935)" do
    assert_type(%(
      $x = uninitialized Int32

      def foo
        $x
      end

      foo
      )) { int32 }
  end
end
