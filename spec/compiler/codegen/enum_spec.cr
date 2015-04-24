require "../../spec_helper"

describe "Code gen: enum" do
  it "codegens enum" do
    expect(run(%(
      enum Foo
        A = 1
      end

      Foo::A
      )).to_i).to eq(1)
  end

  it "codegens enum without explicit value" do
    expect(run(%(
      enum Foo
        A
        B
        C
      end

      Foo::C
      )).to_i).to eq(2)
  end

  it "codegens enum value" do
    expect(run(%(
      enum Foo
        A = 1
      end

      Foo::A.value
      )).to_i).to eq(1)
  end

  it "creates enum from value" do
    expect(run(%(
      enum Foo
        A
        B
      end

      Foo.new(1).value
      )).to_i).to eq(1)
  end

  it "codegens enum bitflags (1)" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
      end

      Foo::A
      )).to_i).to eq(1)
  end

  it "codegens enum bitflags (2)" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
        B
      end

      Foo::B
      )).to_i).to eq(2)
  end

  it "codegens enum bitflags (4)" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
        B
        C
      end

      Foo::C
      )).to_i).to eq(4)
  end

  it "codegens enum bitflags None" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
      end

      Foo::None
      )).to_i).to eq(0)
  end

  it "codegens enum bitflags All" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
        B
        C
      end

      Foo::All
      )).to_i).to eq(1 + 2 + 4)
  end

  it "codegens enum None redefined" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
        None = 10
      end

      Foo::None
      )).to_i).to eq(10)
  end

  it "codegens enum All redefined" do
    expect(run(%(
      @[Flags]
      enum Foo
        A
        All = 10
      end

      Foo::All
      )).to_i).to eq(10)
  end

  it "allows class vars in enum" do
    expect(run(%(
      enum Foo
        A

        @@class_var = 1

        def self.class_var
          @@class_var
        end
      end

      Foo.class_var
      )).to_i).to eq(1)
  end
end
