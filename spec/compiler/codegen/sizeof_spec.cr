require "../../spec_helper"

describe "Code gen: sizeof" do
  it "gets sizeof int" do
    run("sizeof(Int32)").to_i.should eq(4)
  end

  it "gets sizeof struct" do
    run("
      struct Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i.should eq(12)
  end

  it "gets sizeof class" do
    run("
      class Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i.should eq(8)
  end

  it "gets sizeof union" do
    run("
      sizeof(Int32 | Float64)
      ").to_i.should eq(16)
  end

  it "gets sizeof class" do
    run("
      class Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      sizeof(Foo)
      ").to_i.should eq(8)
  end

  it "gets instance_sizeof class" do
    run("
      class Foo
        def initialize(@x, @y, @z)
        end
      end

      Foo.new(1, 2, 3)

      instance_sizeof(Foo)
      ").to_i.should eq(16)
  end

  it "gives error if using instance_sizeof on something that's not a class" do
    assert_error "instance_sizeof(Int32)", "Int32 is not a class, it's a struct"
  end
end
