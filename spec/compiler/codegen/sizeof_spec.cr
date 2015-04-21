require "../../spec_helper"

describe "Code gen: sizeof" do
  it "gets sizeof int" do
    expect(run("sizeof(Int32)").to_i).to eq(4)
  end

  it "gets sizeof struct" do
    expect(run("
      struct Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i).to eq(12)
  end

  it "gets sizeof class" do
    # A class is represented as a pointer to its data
    expect(run("
      class Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i).to eq(sizeof(Void*))
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
    ifdef x86_64
      expect(size).to eq(16)
    else
      expect(size).to eq(12)
    end
  end

  it "gets instance_sizeof class" do
    expect(run("
      class Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      instance_sizeof(Foo)
      ").to_i).to eq(16)
  end

  it "gives error if using instance_sizeof on something that's not a class" do
    assert_error "instance_sizeof(Int32)", "Int32 is not a class, it's a struct"
  end

  it "gets sizeof Void" do
    # Same as the size of a byte
    expect(run("sizeof(Void)").to_i).to eq(1)
  end

  it "gets sizeof NoReturn" do
    # Same as the size of a byte
    expect(run("sizeof(NoReturn)").to_i).to eq(1)
  end
end
