require "../../spec_helper"

describe "Code gen: no return" do
  it "codegens if with NoReturn on then and union on else" do
    run("lib LibC; fun exit(c : Int32) : NoReturn; end; (if 1 == 2; LibC.exit(1); else; 1 || 2.5; end).to_i!").to_i.should eq(1)
  end

  it "codegens Pointer(NoReturn).malloc" do
    run("Pointer(NoReturn).malloc(1_u64); 1").to_i.should eq(1)
  end

  it "codegens if with no return and variable used afterwards" do
    codegen(%(
      require "prelude"

      lib LibC
        fun exit2 : NoReturn
      end

      if (a = LibC.exit2) && a.size == 3
      end
      ))
  end

  it "codegen types exception handler as NoReturn if ensure is NoReturn" do
    codegen(%(
      require "prelude"

      lib LibC
        fun foo : NoReturn
      end

      begin
        1
      ensure
        LibC.foo
      end
      ))
  end

  it "codegens no return variable declaration (#1508)" do
    run(%(
      foo = uninitialized NoReturn
      1
      )).to_i.should eq(1)
  end

  it "codegens no return instance variable declaration (#1508)" do
    run(%(
      class Foo
        def initialize
          @foo = uninitialized NoReturn
          @x = 1
        end

        def x
          @x
        end
      end

      Foo.new.x
      )).to_i.should eq(1)
  end

  it "codegens call with no return because of falsey if (#3661)" do
    codegen(%(
      lib LibC
        fun exit(Int32) : NoReturn
      end

      def bar(x)
        x
      end

      def foo
        bar(yield 1)
      end

      foo do |x|
        LibC.exit(0) unless false
      end
      ))
  end

  it "codegens untyped typeof (#5105)" do
    codegen(%(
      require "prelude"

      typeof(raise("").foo)
      ))
  end
end
