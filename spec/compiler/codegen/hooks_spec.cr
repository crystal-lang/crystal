require "../../spec_helper"

describe "Code gen: hooks" do
  it "does inherited macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        macro inherited
          @@x = 1

          def self.x
            @@x
          end
        end
      end

      class Bar < Foo
      end

      Bar.x
      CRYSTAL
  end

  it "does included macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      module Foo
        macro included
          @@x = 1

          def self.x
            @@x
          end
        end
      end

      class Bar
        include Foo
      end

      Bar.x
      CRYSTAL
  end

  it "does extended macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      module Foo
        macro extended
          @@x = 1

          def self.x
            @@x
          end
        end
      end

      class Bar
        extend Foo
      end

      Bar.x
      CRYSTAL
  end

  it "does added method macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      class Foo
        macro method_added(d)
          Global.x = 1
        end

        def foo; end
      end

      Global.x
      CRYSTAL
  end

  it "does inherited macro recursively" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      class Foo
        macro inherited
          Global.x &+= 1
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      Global.x
      CRYSTAL
  end

  it "does inherited macro before class body" do
    run(<<-CRYSTAL).to_i.should eq(123)
      require "prelude"

      class Global
        @@x = 123

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      class Foo
        macro inherited
          @@y : Int32 = Global.x

          def self.y
            @@y
          end
        end
      end

      class Bar < Foo
        Global.x &+= 1
      end

      Bar.y
      CRYSTAL
  end

  it "does finished" do
    run(<<-CRYSTAL).to_i.should eq(4)
      class Foo
        A = [1]

        macro finished
          {% A[0] = A[0] + 1 %}
        end

        macro finished
          {% A[0] = A[0] * 2 %}
        end

        macro finished
          def self.foo
            {{ A[0] }}
          end
        end
      end

      Foo.foo
      CRYSTAL
  end

  it "fixes empty types in hooks (#3946)" do
    codegen(<<-CRYSTAL)
      lib LibC
        fun exit(x : Int32) : NoReturn
      end

      def bar(x)
      end

      module Moo
        def foo
          bar(moo)
        end
      end

      class Moo1
        include Moo

        def moo
          0
        end
      end

      class Moo2
        include Moo

        def moo
          LibC.exit(1)
        end
      end

      class Foo
        macro inherited
          io = uninitialized Moo
          io.foo
        end
      end

      class Bar < Foo
      end
      CRYSTAL
  end
end
