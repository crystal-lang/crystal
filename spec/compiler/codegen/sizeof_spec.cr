require "../../spec_helper"

describe "Code gen: sizeof" do
  it "gets sizeof int" do
    run("sizeof(Int32)").to_i.should eq(4)
  end

  it "gets sizeof struct" do
    run("
      struct Foo
        def initialize(@x : Int32, @y : Int32, @z : Int32)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i.should eq(12)
  end

  it "gets sizeof class" do
    # A class is represented as a pointer to its data
    run("
      class Foo
        def initialize(@x : Int32, @y : Int32, @z : Int32)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i.should eq(sizeof(Void*))
  end

  it "gets sizeof union" do
    size = run("
      sizeof(Int32 | Float64)
      ").to_i

    # This union is represented as:
    #
    #   struct {
    #      4 bytes, # for the type id
    #      8 bytes, # for the largest size between Int32 and Float64
    #   }
    #
    # But in 64 bits structs are aligned to 8 bytes, so it'll actually
    # be struct { 8 bytes, 8 bytes }.
    #
    # In 32 bits structs are aligned to 4 bytes, so it remains the same.
    {% if flag?(:bits64) %}
      size.should eq(16)
    {% else %}
      size.should eq(12)
    {% end %}
  end

  it "gets instance_sizeof class" do
    run("
      class Foo
        def initialize(@x : Int32, @y : Int32, @z : Int32)
        end
      end

      Foo.new(1, 2, 3)

      instance_sizeof(Foo)
      ").to_i.should eq(16)
  end

  it "gets instance_sizeof a generic type with type vars" do
    run(%(
      class Foo(T)
        def initialize(@x : T)
        end
      end

      instance_sizeof(Foo(Int32))
      )).to_i.should eq(8)
  end

  it "gets sizeof Void" do
    # Same as the size of a byte, because doing
    # `Pointer(Void).malloc` must work like `Pointer(UInt8).malloc`
    run("sizeof(Void)").to_i.should eq(1)
  end

  it "gets sizeof NoReturn" do
    # NoReturn can't hold anything
    run("sizeof(NoReturn)").to_i.should eq(0)
  end

  it "gets sizeof Nil (#7644)" do
    # Nil can't hold anything
    run("sizeof(Nil)").to_i.should eq(0)
  end

  it "gets sizeof Bool (#8272)" do
    run("sizeof(Bool)").to_i.should eq(1)
  end

  it "can use sizeof in type argument (1)" do
    run(%(
      struct StaticArray
        def size
          N
        end
      end

      x = uninitialized UInt8[sizeof(Int32)]
      x.size
      )).to_i.should eq(4)
  end

  it "can use sizeof in type argument (2)" do
    run(%(
      struct StaticArray
        def size
          N
        end
      end

      x = uninitialized UInt8[sizeof(Float64)]
      x.size
      )).to_i.should eq(8)
  end

  it "can use sizeof of virtual type" do
    size = run(%(
      class Foo
        @x = 1
      end

      class Bar < Foo
        @y = 2
      end

      foo = Bar.new.as(Foo)
      sizeof(typeof(foo))
      )).to_i

    {% if flag?(:bits64) %}
      size.should eq(8)
    {% else %}
      size.should eq(4)
    {% end %}
  end

  it "can use instance_sizeof of virtual type" do
    run(%(
      class Foo
        @x = 1
      end

      class Bar < Foo
        @y = 2
      end

      class Baz < Bar
        @z = 2
      end

      bar = Baz.new.as(Bar)
      instance_sizeof(typeof(bar))
      )).to_i.should eq(12)
  end

  it "can use instance_sizeof in type argument" do
    run(%(
      struct StaticArray
        def size
          N
        end
      end

      class Foo
        def initialize
          @x = 1
          @y = 1
        end
      end

      x = uninitialized UInt8[instance_sizeof(Foo)]
      x.size
      )).to_i.should eq(12)
  end

  it "returns correct sizeof for abstract struct (#4319)" do
    size = run(%(
        abstract struct Entry
        end

        struct FooEntry < Entry
          def initialize
            @uid = ""
          end
        end

        struct BarEntry < Entry
          def initialize
            @uid = ""
          end
        end

        sizeof(Entry)
        )).to_i

    size.should eq(16)
  end

  it "doesn't precompute sizeof of abstract struct (#7741)" do
    run(%(
      abstract struct Base
      end

      struct Foo(T) < Base
        def initialize(@x : T)
        end
      end

      z = sizeof(Base)

      Foo({Int32, Int32, Int32, Int32})

      z)).to_i.should eq(16)
  end

  it "doesn't precompute sizeof of module (#7741)" do
    run(%(
      module Base
      end

      struct Foo(T)
        include Base

        def initialize(@x : T)
        end
      end

      z = sizeof(Base)

      Foo({Int32, Int32, Int32, Int32})

      z)).to_i.should eq(16)
  end

  describe "alignof" do
    it "gets alignof primitive types" do
      run("alignof(Int32)").to_i.should eq(4)
      run("alignof(Void)").to_i.should eq(1)
      run("alignof(NoReturn)").to_i.should eq(1)
      run("alignof(Nil)").to_i.should eq(1)
      run("alignof(Bool)").to_i.should eq(1)
    end

    it "gets alignof struct" do
      run(<<-CRYSTAL).to_i.should eq(4)
        struct Foo
          def initialize(@x : Int8, @y : Int32, @z : Int16)
          end
        end

        Foo.new(1, 2, 3)

        alignof(Foo)
        CRYSTAL
    end

    it "gets alignof class" do
      # pointer size and alignment should be identical
      run(<<-CRYSTAL).to_i.should eq(sizeof(Void*))
        class Foo
          def initialize(@x : Int8, @y : Int32, @z : Int16)
          end
        end

        Foo.new(1, 2, 3)

        alignof(Foo)
        CRYSTAL
    end

    it "gets alignof union" do
      run("alignof(Int32 | Int8)").to_i.should eq(8)
      run("alignof(Int32 | Int64)").to_i.should eq(8)
    end

    it "alignof mixed union is not less than alignof its variant types" do
      # NOTE: `alignof(Int128) == 16` is not guaranteed
      run("alignof(Int32 | Int128) >= alignof(Int128)").to_b.should be_true
    end
  end

  describe "instance_alignof" do
    it "gets instance_alignof class" do
      run(<<-CRYSTAL).to_i.should eq(4)
        class Foo
          def initialize(@x : Int8, @y : Int32, @z : Int16)
          end
        end

        Foo.new(1, 2, 3)

        instance_alignof(Foo)
        CRYSTAL

      run(<<-CRYSTAL).to_i.should eq(8)
        class Foo
          def initialize(@x : Int8, @y : Int64, @z : Int16)
          end
        end

        Foo.new(1, 2, 3)

        instance_alignof(Foo)
        CRYSTAL

      run(<<-CRYSTAL).to_i.should eq(4)
        class Foo
        end

        Foo.new

        instance_alignof(Foo)
        CRYSTAL
    end

    it "gets instance_alignof a generic type with type vars" do
      run(<<-CRYSTAL).to_i.should eq(4)
        class Foo(T)
          def initialize(@x : T)
          end
        end

        instance_alignof(Foo(Int32))
        CRYSTAL

      run(<<-CRYSTAL).to_i.should eq(8)
        class Foo(T)
          def initialize(@x : T)
          end
        end

        instance_alignof(Foo(Int64))
        CRYSTAL

      run(<<-CRYSTAL).to_i.should eq(4)
        class Foo(T)
          def initialize(@x : T)
          end
        end

        instance_alignof(Foo(Int8))
        CRYSTAL
    end
  end
end
