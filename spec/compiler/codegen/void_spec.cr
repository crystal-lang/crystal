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
    build("
      lib C
        fun exit : NoReturn
      end

      a = C.exit
      a
      ")
  end
end
