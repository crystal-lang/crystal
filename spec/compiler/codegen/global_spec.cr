require "../../spec_helper"

describe "Code gen: global" do
  it "codegens global" do
    run("$foo = 1; def foo; $foo = 2; end; foo; $foo").to_i.should eq(2)
  end

  it "codegens global with union" do
    run("$foo = 1; def foo; $foo = 2.5_f32; end; foo; $foo.to_f").to_f64.should eq(2.5)
  end

  it "codegens global when not initialized" do
    run(%(
      struct Nil; def to_i; 0; end; end
      $foo : Int32?
      $foo.to_i
      )).to_i.should eq(0)
  end

  it "codegens global when not initialized" do
    run(%(
      struct Nil; def to_i; 0; end; end

      def foo
        $foo = 2 if 1 == 2
      end

      foo

      $foo.to_i
      )).to_i.should eq(0)
  end

  it "declares and initializes" do
    run(%(
      $x : Int32 = 42
      $x : Int32 = 84
      $x
      )).to_i.should eq(84)
  end

  it "doesn't crash on global declaration (#2619)" do
    run(%(
      struct Foo
        def initialize(@value : Int32)
        end

        def value
          @value
        end
      end

      $one : Foo = Foo.new(42)

      def foo
      end

      $one.value
      )).to_i.should eq(42)
  end

  it "declares var as uninitialized and initializes it unsafely" do
    run(%(
      def bar
        if 1 == 2
          $x
        else
          10
        end
      end

      $x = uninitialized Int32
      $x = bar
      $x
      )).to_i.should eq(10)
  end
end
