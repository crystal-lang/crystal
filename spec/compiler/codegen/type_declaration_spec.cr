require "../../spec_helper"

describe "Code gen: type declaration" do
  it "codegens initialize instance var" do
    run("
      class Foo
        @x = 1

        def x
          @x
        end
      end

      Foo.new.x
      ").to_i.should eq(1)
  end

  it "codegens initialize instance var of superclass" do
    run("
      class Foo
        @x = 1

        def x
          @x
        end
      end

      class Bar < Foo
      end

      Bar.new.x
      ").to_i.should eq(1)
  end

  it "codegens initialize instance var with var declaration" do
    run("
      class Foo
        @x = begin
          a = 1
          a
        end

        def x
          @x
        end
      end

      Foo.new.x
      ").to_i.should eq(1)
  end
end
