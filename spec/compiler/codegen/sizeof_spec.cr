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
    {% if flag?(:x86_64) %}
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

  it "gives error if using instance_sizeof on something that's not a class" do
    assert_error "instance_sizeof(Int32)", "Int32 is not a class, it's a struct"
  end

  it "gets sizeof Void" do
    # Same as the size of a byte
    run("sizeof(Void)").to_i.should eq(1)
  end

  it "gets sizeof NoReturn" do
    # Same as the size of a byte
    run("sizeof(NoReturn)").to_i.should eq(1)
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

    {% if flag?(:x86_64) %}
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

  {% if flag?(:x86_64) %}
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
  {% end %}
end
