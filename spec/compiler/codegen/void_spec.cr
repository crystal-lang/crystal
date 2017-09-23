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

      def baz
        LibC.foo
      end

      bar(baz)
    ))
  end

  it "returns void from nil functions, doesn't crash when passing value" do
    run(%(
      def baz(x)
        1
      end

      struct Nil
        def bar
          baz(self)
        end
      end

      def foo
        1
        nil
      end

      foo.bar
      )).to_i.should eq(1)
  end
end
