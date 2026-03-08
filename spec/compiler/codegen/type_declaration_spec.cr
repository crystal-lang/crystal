require "../../spec_helper"

describe "Code gen: type declaration" do
  it "codegens initialize instance var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @x = 1

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "codegens initialize instance var of superclass" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @x = 1

        def x
          @x
        end
      end

      class Bar < Foo
      end

      Bar.new.x
      CRYSTAL
  end

  it "codegens initialize instance var with var declaration" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        @x : Int32 = begin
          a = 1
          a
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "declares and initializes" do
    run(<<-CRYSTAL).to_i.should eq(42)
      class Foo
        @x : Int32 = 42

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "declares and initializes var" do
    run(<<-CRYSTAL).to_i.should eq(42)
      a : Int32 = 42
      a
      CRYSTAL
  end
end
