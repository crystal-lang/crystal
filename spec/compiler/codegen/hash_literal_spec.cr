require "../../spec_helper"

describe "Code gen: hash literal spec" do
  it "creates custom non-generic hash" do
    run(<<-CRYSTAL).to_i.should eq(90)
      class Custom
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys &+= key
          @values &+= value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      custom = Custom {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "creates custom generic hash" do
    run(<<-CRYSTAL).to_i.should eq(90)
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys &+= key
          @values &+= value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      custom = Custom {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "creates custom generic hash with type vars" do
    run(<<-CRYSTAL).to_i.should eq(90)
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys &+= key
          @values &+= value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      custom = Custom(Int32, Int32) {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "creates custom generic hash via alias (1)" do
    run(<<-CRYSTAL).to_i.should eq(90)
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys &+= key
          @values &+= value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      alias MyCustom = Custom

      custom = MyCustom {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "creates custom generic hash via alias (2)" do
    run(<<-CRYSTAL).to_i.should eq(90)
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys &+= key
          @values &+= value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      alias MyCustom = Custom(Int32, Int32)

      custom = MyCustom {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "doesn't crash on hash literal with proc pointer (#646)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      def blah
        1
      end

      b = {"a" => ->blah}
      b["a"].call
      CRYSTAL
  end

  it "creates custom non-generic hash in module" do
    run(<<-CRYSTAL).to_i.should eq(90)
      module Moo
        class Custom
          def initialize
            @keys = 0
            @values = 0
          end

          def []=(key, value)
            @keys &+= key
            @values &+= value
          end

          def keys
            @keys
          end

          def values
            @values
          end
        end
      end

      custom = Moo::Custom {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "creates custom generic hash in module (#5684)" do
    run(<<-CRYSTAL).to_i.should eq(90)
      module Moo
        class Custom(K, V)
          def initialize
            @keys = 0
            @values = 0
          end

          def []=(key, value)
            @keys &+= key
            @values &+= value
          end

          def keys
            @keys
          end

          def values
            @values
          end
        end
      end

      custom = Moo::Custom {1 => 10, 2 => 20}
      custom.keys &* custom.values
      CRYSTAL
  end

  it "assignment in hash literal works" do
    run("require \"prelude\"; {k = 1 => v = 2}; k + v").to_i.should eq(3)
  end

  it "assignment in hash-like literal works" do
    run("require \"prelude\"; Hash(Int32, Int32){k = 1 => v = 2}; k + v").to_i.should eq(3)
  end
end
