require "../../spec_helper"

private def assert_commutes(str, *, file = __FILE__, line = __LINE__, &)
  result = semantic(str)
  program = result.program
  type1, type2, expected = with program yield program
  union1 = program.type_merge([type1, type2])
  union2 = program.type_merge([type2, type1])
  union1.should eq(expected), file: file, line: line
  union2.should eq(expected), file: file, line: line
end

describe "Semantic: union" do
  context "commutativity" do
    it "module v.s. including module" do
      assert_commutes(%(
        module A
        end

        module B
          include A
        end
        )) { [types["A"], types["B"], types["A"]] }
    end

    it "module v.s. including generic module instance" do
      assert_commutes(%(
        class Cxx
        end

        module A
        end

        module B(T)
          include A
        end
        )) { [types["A"], generic_module("B", types["Cxx"]), types["A"]] }
    end

    it "generic module instance v.s. including module" do
      assert_commutes(%(
        class Cxx
        end

        module A(T)
        end

        module B
          include A(Cxx)
        end
        )) { [generic_module("A", types["Cxx"]), types["B"], generic_module("A", types["Cxx"])] }
    end

    it "generic module instance v.s. including generic module instance" do
      assert_commutes(%(
        class Cxx
        end

        module A(T)
        end

        module B(T)
          include A(T)
        end
        )) { [generic_module("A", types["Cxx"]), generic_module("B", types["Cxx"]), generic_module("A", types["Cxx"])] }
    end

    it "module v.s. extending generic module instance metaclass" do
      assert_commutes(%(
        class Cxx
        end

        module A
        end

        module B(T)
          extend A
        end
        )) { [types["A"], generic_module("B", types["Cxx"]).metaclass, types["A"]] }
    end

    it "generic module instance v.s. extending generic module instance metaclass" do
      assert_commutes(%(
        class Cxx
        end

        module A(T)
        end

        module B(T)
          extend A(T)
        end
        )) { [generic_module("A", types["Cxx"]), generic_module("B", types["Cxx"]).metaclass, generic_module("A", types["Cxx"])] }
    end

    it "virtual metaclass v.s. generic subclass instance metaclass" do
      assert_commutes(%(
        class Cxx
        end

        class A
        end

        class B(T) < A
        end
        )) { [types["A"].virtual_type!.metaclass, generic_class("B", types["Cxx"]).metaclass, types["A"].virtual_type!.metaclass] }
    end

    it "superclass v.s. uninstantiated generic subclass" do
      assert_commutes(%(
        class A
        end

        class B(T) < A
        end
        )) { [types["A"], types["B"], types["A"].virtual_type!] }
    end

    it "uninstantiated generic super-metaclass v.s. uninstantiated generic sub-metaclass" do
      assert_commutes(%(
        class A(T)
        end

        class B(T) < A(T)
        end
        )) { [types["A"].metaclass, types["B"].metaclass, types["A"].metaclass.virtual_type!] }
    end
  end

  it "types union when obj is union" do
    assert_type("struct Char; def +(other); self; end; end; a = 1 || 'a'; a + 1", inject_primitives: true) { union_of(int32, char) }
  end

  it "types union when arg is union" do
    assert_type("struct Int; def +(x : Char); x; end; end; a = 1 || 'a'; 1 + a", inject_primitives: true) { union_of(int32, char) }
  end

  it "types union when both obj and arg are union" do
    assert_type("struct Char; def +(other); self; end; end; struct Int; def +(x : Char); x; end; end; a = 1 || 'a'; a + a", inject_primitives: true) { union_of(int32, char) }
  end

  it "types union of classes" do
    assert_type("class Foo; end; class Bar; end; a = Foo.new || Bar.new; a") { union_of(types["Foo"], types["Bar"]) }
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

      def foo(x : T) forall T
        Bar(T).new
      end

      foo(1 || 'a')
    ") { generic_class "Bar", union_of(int32, char) }
  end

  it "supports macro if inside union" do
    assert_type(%(
      lib LibC
        union Foo
          {% if flag?(:some_flag) %}
            a : Int32
          {% else %}
            a : Float64
          {% end %}
        end
      end

      LibC::Foo.new.a
      ), flags: "some_flag") { int32 }
  end

  it "types union" do
    assert_type(%(
      Union(Int32, String)
      )) { union_of(int32, string).metaclass }
  end

  it "types union of same type" do
    assert_type(%(
      Union(Int32, Int32, Int32)
      )) { int32.metaclass }
  end

  it "can reopen Union" do
    assert_type(%(
      struct Union
        def self.foo
          1
        end
      end
      Union(Int32, String).foo
      )) { int32 }
  end

  it "can reopen Union and access T" do
    assert_type(%(
      struct Union
        def self.types
          T
        end
      end
      Union(Int32, String).types
      )) { tuple_of([int32, string]).metaclass }
  end

  it "can iterate T" do
    assert_type(%(
      struct Union
        def self.types
          {% begin %}
            {
              {% for type in T %}
                {{type}},
              {% end %}
            }
          {% end %}
        end
      end
      Union(Int32, String).types
      )) { tuple_of([int32.metaclass, string.metaclass]) }
  end

  it "errors if instantiates union" do
    assert_error %(
      Union(Int32, String).new
      ),
      "can't create instance of a union type"
  end

  it "finds method in Object" do
    assert_type(%(
      class Object
        def self.foo
          1
        end
      end

      Union(Int32, String).foo
      )) { int32 }
  end

  it "finds method in Value" do
    assert_type(%(
      struct Value
        def self.foo
          1
        end
      end

      Union(Int32, String).foo
      )) { int32 }
  end

  it "merges types in the same hierarchy with Union" do
    assert_type(%(
      class Foo; end
      class Bar < Foo; end

      Union(Foo, Bar)
      )) { types["Foo"].virtual_type!.metaclass }
  end

  it "treats void as nil in union" do
    assert_type(%(
      nil.as(Void?)
      )) { nil_type }
  end

  it "can use Union in type restriction (#2988)" do
    assert_type(%(
      def foo(x : Union(Int32, String))
        x
      end

      {foo(1), foo("hi")}
      )) { tuple_of([int32, string]) }
  end

  it "doesn't crash with union of no-types (#5805)" do
    assert_type(%(
      class Gen(T)
      end

      foo = 42
      if foo.is_a?(String)
        Gen(typeof(foo) | Int32)
      else
        'a'
      end
      )) { union_of char, generic_class("Gen", int32).metaclass }
  end

  it "doesn't virtualize union elements (#7814)" do
    assert_type(%(
      class Foo; end
      class Bar < Foo; end

      Union(Foo)
      )) { types["Foo"].metaclass }
  end

  it "doesn't run virtual lookup on unbound unions (#9173)" do
    assert_type(%(
      class Object
        def foo
          self
        end
      end

      abstract class Parent
      end

      class Child(T) < Parent
        @buffer = uninitialized T

        def bar
          @buffer.foo
        end
      end

      class Foo(U)
        @x = Child(U | Char).new
      end

      Child(Int32).new.as(Parent).bar
      )) { int32 }
  end
end
