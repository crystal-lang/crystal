require "../../spec_helper"

describe "Code gen: prepend" do
  it "prepended module method takes precedence over the class's own" do
    run(<<-CRYSTAL).to_string.should eq("from prepended")
      require "prelude"

      module Prepended
        def foo
          "from prepended"
        end
      end

      class Subclass
        prepend Prepended

        def foo
          "from class"
        end
      end

      Subclass.new.foo
      CRYSTAL
  end

  it "super inside a prepended method calls the class's own method" do
    run(<<-CRYSTAL).to_string.should eq("Prepended -> Subclass")
      require "prelude"

      module Prepended
        def foo
          "Prepended -> " + super
        end
      end

      class Subclass
        prepend Prepended

        def foo
          "Subclass"
        end
      end

      Subclass.new.foo
      CRYSTAL
  end

  it "follows Ruby's full chain: prepend -> class -> include -> superclass" do
    # This is the example from issue #10504.
    run(<<-CRYSTAL).to_string.should eq("Prepend\nSubclass\nIncluded\nBase\n")
      require "prelude"

      class Base
        def foo
          "Base"
        end
      end

      module Included
        def foo
          "Included\\n" + super
        end
      end

      module Prepend
        def foo
          "Prepend\\n" + super
        end
      end

      class Subclass < Base
        prepend Prepend
        include Included

        def foo
          "Subclass\\n" + super
        end
      end

      Subclass.new.foo + "\\n"
      CRYSTAL
  end

  it "uses the last-prepended module first (multiple prepends)" do
    run(<<-CRYSTAL).to_string.should eq("P2\nP1\nC\n")
      require "prelude"

      module P1
        def foo
          "P1\\n" + super
        end
      end

      module P2
        def foo
          "P2\\n" + super
        end
      end

      class C
        prepend P1
        prepend P2

        def foo
          "C"
        end
      end

      C.new.foo + "\\n"
      CRYSTAL
  end

  it "lets the prepended module observe an instance variable set in the class" do
    run(<<-CRYSTAL).to_i.should eq(42)
      require "prelude"

      module Prepended
        def value
          super * 2
        end
      end

      class C
        prepend Prepended

        def initialize
          @x = 21
        end

        def value
          @x
        end
      end

      C.new.value
      CRYSTAL
  end
end
