require "../../spec_helper"

describe "Code gen: enum" do
  it "codegens enum" do
    run(%(
      enum Foo
        A = 1
      end

      Foo::A
      )).to_i.should eq(1)
  end

  it "codegens enum without explicit value" do
    run(%(
      enum Foo
        A
        B
        C
      end

      Foo::C
      )).to_i.should eq(2)
  end

  it "codegens enum value" do
    run(%(
      enum Foo
        A = 1
      end

      Foo::A.value
      )).to_i.should eq(1)
  end

  it "creates enum from value" do
    run(%(
      enum Foo
        A
        B
      end

      Foo.new(1).value
      )).to_i.should eq(1)
  end

  it "codegens enum bitflags (1)" do
    run(%(
      @[Flags]
      enum Foo
        A
      end

      Foo::A
      )).to_i.should eq(1)
  end

  it "codegens enum bitflags (2)" do
    run(%(
      @[Flags]
      enum Foo
        A
        B
      end

      Foo::B
      )).to_i.should eq(2)
  end

  it "codegens enum bitflags (4)" do
    run(%(
      @[Flags]
      enum Foo
        A
        B
        C
      end

      Foo::C
      )).to_i.should eq(4)
  end

  it "codegens enum bitflags None" do
    run(%(
      @[Flags]
      enum Foo
        A
      end

      Foo::None
      )).to_i.should eq(0)
  end

  it "codegens enum bitflags All" do
    run(%(
      @[Flags]
      enum Foo
        A
        B
        C
      end

      Foo::All
      )).to_i.should eq(1 + 2 + 4)
  end

  it "codegens enum None redefined" do
    run(%(
      @[Flags]
      enum Foo
        A
        None = 10
      end

      Foo::None
      )).to_i.should eq(10)
  end

  it "codegens enum All redefined" do
    run(%(
      @[Flags]
      enum Foo
        A
        All = 10
      end

      Foo::All
      )).to_i.should eq(10)
  end
end
