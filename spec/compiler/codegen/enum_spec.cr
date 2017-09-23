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
      lib Lib
        @[Flags]
        enum Foo
          A
          None = 10
        end
      end

      Lib::Foo::None
      )).to_i.should eq(10)
  end

  it "codegens enum All redefined" do
    run(%(
      lib Lib
        @[Flags]
        enum Foo
          A
          All = 10
        end
      end

      Lib::Foo::All
      )).to_i.should eq(10)
  end

  it "allows class vars in enum" do
    run(%(
      enum Foo
        A

        @@class_var = 1

        def self.class_var
          @@class_var
        end
      end

      Foo.class_var
      )).to_i.should eq(1)
  end

  it "automatically defines question method for each enum member (false case)" do
    run(%(
      struct Enum
        def ==(other : self)
          value == other.value
        end
      end

      enum Day
        SomeMonday
        SomeTuesday
      end

      day = Day::SomeTuesday
      day.some_monday?
      )).to_b.should be_false
  end

  it "automatically defines question method for each enum member (true case)" do
    run(%(
      struct Enum
        def ==(other : self)
          value == other.value
        end
      end

      enum Day
        SomeMonday
        SomeTuesday
      end

      day = Day::SomeTuesday
      day.some_tuesday?
      )).to_b.should be_true
  end

  it "automatically defines question method for each enum member (flags, false case)" do
    run(%(
      struct Enum
        def includes?(other : self)
          (value & other.value) != 0
        end
      end

      @[Flags]
      enum Day
        SomeMonday
        SomeTuesday
        SomeWednesday
      end

      day = Day.new(3)
      day.some_wednesday?
      )).to_b.should be_false
  end

  it "automatically defines question method for each enum member (flags, true case)" do
    run(%(
      struct Enum
        def includes?(other : self)
          (value & other.value) != 0
        end
      end

      @[Flags]
      enum Day
        SomeMonday
        SomeTuesday
        SomeWednesday
      end

      day = Day.new(3)
      day.some_tuesday?
      )).to_b.should be_true
  end

  it "does ~ at compile time for enum member" do
    run(%(
      enum Foo
        Bar = ~1
      end

      Foo::Bar.value
      )).to_i.should eq(~1)
  end

  it "uses enum value before declaration (hoisting)" do
    run(%(
      x = Bar.bar

      enum Foo
        A = 1
      end

      class Bar
        def self.bar
          Foo::A
        end
      end

      x
      )).to_i.should eq(1)
  end

  it "casts All value to base type" do
    run(%(
      @[Flags]
      enum Foo
        A = 1 << 30
        B = 1 << 31
      end

      Foo::All.value
      )).to_i.should eq(-1073741824)
  end

  it "can use macro calls inside enum value (#424)" do
    run(%(
      enum Foo
        macro bar
          10 + 20
        end

        A = bar
      end

      Foo::A.value
      )).to_i.should eq(30)
  end

  it "can use macro calls inside enum value, macro defined outside enum (#424)" do
    run(%(
      macro bar
        10 + 20
      end

      enum Foo
        A = bar
      end

      Foo::A.value
      )).to_i.should eq(30)
  end

  it "can use macro calls inside enum value, with receiver (#424)" do
    run(%(
      module Moo
        macro bar
          10 + 20
        end
      end

      enum Foo
        A = Moo.bar
      end

      Foo::A.value
      )).to_i.should eq(30)
  end

  it "adds a none? method to flags enum" do
    run(%(
      @[Flags]
      enum Foo
        A
        B
      end

      x = 0
      x += 1 if Foo::None.none?
      x += 2 if Foo::A.none?
      x
      )).to_i.should eq(1)
  end
end
