require "../../spec_helper"

describe "Code gen: void" do
  it "codegens void assignment" do
    run("
      fun foo : Void
      end

      a = foo
      a
      1
      ").to_i.should eq(1)
  end

  it "codegens void assignment in case" do
    run("
      require \"prelude\"

      fun foo : Void
      end

      def bar
        case 1
        when 1
          foo
        when 2
          raise \"oh no\"
        end
      end

      bar
      1
      ").to_i.should eq(1)
  end

  it "codegens void assignment in case with local variable" do
    run("
      require \"prelude\"

      fun foo : Void
      end

      def bar
        case 1
        when 1
          a = 1
          foo
        when 2
          raise \"oh no\"
        end
      end

      bar
      1
      ").to_i.should eq(1)
  end

  it "codegens unreachable code" do
    run(%(
      a = nil
      if a
        b = a.foo
      end
      ))
  end

  it "codegens no return assignment" do
    codegen("
      lib LibC
        fun exit : NoReturn
      end

      a = LibC.exit
      a
      ")
  end

  it "allows passing void as argument to method" do
    codegen(%(
      lib LibC
        fun foo
      end

      def bar(x)
      end

      bar LibC.foo
    ))
  end

  it "uses ||=" do
    codegen(%(
      lib LibFoo
        fun foo
      end

      a = LibFoo.foo
      a ||= 2
      a
      ))
  end

  it "uses void return type" do
    codegen(%(
      def foo : Void
      end

      foo
      ))
  end

  it "is falsey" do
    run(%(
      def foo : Void
      end

      if foo
        10
      else
        42
      end
      )).to_i.should eq(42)
  end
end
