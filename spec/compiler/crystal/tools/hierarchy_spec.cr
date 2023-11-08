require "../../../spec_helper"

private def assert_text_hierarchy(source, filter, expected, *, file = __FILE__, line = __LINE__)
  program = semantic(source).program
  output = String.build { |io| Crystal.print_hierarchy(program, io, filter, "text") }
  output.should eq(expected), file: file, line: line
end

private def assert_json_hierarchy(source, filter, expected, *, file = __FILE__, line = __LINE__)
  program = semantic(source).program
  output = String.build { |io| Crystal.print_hierarchy(program, io, filter, "json") }
  JSON.parse(output).should eq(JSON.parse(expected)), file: file, line: line
end

describe Crystal::TextHierarchyPrinter do
  it "works" do
    assert_text_hierarchy <<-CRYSTAL, "ar$", <<-EOS
      class Foo
      end

      class Bar < Foo
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- class Reference (4 bytes)
           |
           +- class Foo (4 bytes)
              |
              +- class Bar (4 bytes)\n
      EOS
  end

  it "shows correct size for Bool member" do
    assert_text_hierarchy <<-CRYSTAL, "Foo", <<-EOS
      struct Foo
        @x = true
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- struct Value (0 bytes)
           |
           +- struct Struct (0 bytes)
              |
              +- struct Foo (1 bytes)
                     @x : Bool (1 bytes)\n
      EOS
  end

  it "shows correct size for members with bound types" do
    assert_text_hierarchy <<-CRYSTAL, "Foo", <<-EOS
      struct Bar1(T)
        @x = uninitialized T
      end

      class Bar2(T)
        @x = uninitialized T
      end

      module Bar3(T)
        struct I(T)
          include Bar3(T)

          @x = uninitialized T
        end
      end

      module Bar4(T)
        class I(T)
          include Bar3(T)

          @x = uninitialized T
        end
      end

      class Foo(T)
        @a = uninitialized T*
        @b = uninitialized T
        @c = uninitialized T[4]
        @d = uninitialized Int32[T]
        @e = uninitialized T ->
        @f = uninitialized T?
        @g = uninitialized {T}
        @h = uninitialized {x: T}
        @i = uninitialized Bar1(T)
        @j = uninitialized Bar2(T)
        @k = uninitialized Bar3(T)
        @l = uninitialized Bar4(T)
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- class Reference (4 bytes)
           |
           +- class Foo(T)
                  @a : Pointer(T)            ( 8 bytes)
                  @b : T
                  @c : StaticArray(T, 4)
                  @d : StaticArray(Int32, T)
                  @e : Proc(T, Nil)          (16 bytes)
                  @f : (T | Nil)
                  @g : Tuple(T)
                  @h : NamedTuple(x: T)
                  @i : Bar1(T)
                  @j : Bar2(T)               ( 8 bytes)
                  @k : Bar3(T)
                  @l : Bar4(T)               ( 8 bytes)\n
      EOS
  end

  it "shows correct total size of generic class if known" do
    assert_text_hierarchy <<-CRYSTAL, "Foo", <<-EOS
      class Bar1(T)
        @x = uninitialized T
      end

      class Bar2(T)
        @x = uninitialized T
      end

      class Foo(T)
        @a = uninitialized T*
        @b : Bar1(T) | Bar2(T)?
        @c = uninitialized T*[6]
        @d = uninitialized Int64
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- class Reference (4 bytes)
           |
           +- class Foo(T) (80 bytes)
                  @a : Pointer(T)                 ( 8 bytes)
                  @b : (Bar1(T) | Bar2(T) | Nil)  ( 8 bytes)
                  @c : StaticArray(Pointer(T), 6) (48 bytes)
                  @d : Int64                      ( 8 bytes)\n
      EOS
  end

  it "shows correct size for Proc inside extern struct" do
    assert_text_hierarchy <<-CRYSTAL, "Foo", <<-EOS
      @[Extern]
      struct Foo
        @x = uninitialized ->
      end

      lib Bar
        struct Foo
          x : Int32 -> Int32
        end
      end
      CRYSTAL
      - class Object (4 bytes)
        |
        +- struct Value (0 bytes)
           |
           +- struct Struct (0 bytes)
              |
              +- struct Bar::Foo (8 bytes)
              |      @x : Proc(Int32, Int32) (8 bytes)
              |
              +- struct Foo (8 bytes)
                     @x : Proc(Nil) (8 bytes)\n
      EOS
  end
end

describe Crystal::JSONHierarchyPrinter do
  it "works" do
    assert_json_hierarchy <<-CRYSTAL, "ar$", <<-JSON
      class Foo
      end

      class Bar < Foo
      end
      CRYSTAL
      {
        "name": "Object",
        "kind": "class",
        "size_in_bytes": 4,
        "sub_types": [
          {
            "name": "Reference",
            "kind": "class",
            "size_in_bytes": 4,
            "sub_types": [
              {
                "name": "Foo",
                "kind": "class",
                "size_in_bytes": 4,
                "sub_types": [
                  {
                    "name": "Bar",
                    "kind": "class",
                    "size_in_bytes": 4,
                    "sub_types": []
                  }
                ]
              }
            ]
          }
        ]
      }
      JSON
  end
end
