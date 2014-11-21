require "../../spec_helper"

describe "Code gen: hash literal spec" do
  it "creates custom non-generic hash" do
    run(%(
      class Custom
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys += key
          @values += value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      custom = Custom {1 => 10, 2 => 20}
      custom.keys * custom.values
      )).to_i.should eq(90)
  end

  it "creates custom generic hash" do
    run(%(
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys += key
          @values += value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      custom = Custom {1 => 10, 2 => 20}
      custom.keys * custom.values
      )).to_i.should eq(90)
  end

  it "creates custom generic hash with type vars" do
    run(%(
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys += key
          @values += value
        end

        def keys
          @keys
        end

        def values
          @values
        end
      end

      custom = Custom(Int32, Int32) {1 => 10, 2 => 20}
      custom.keys * custom.values
      )).to_i.should eq(90)
  end

  it "creates custom generic hash via alias (1)" do
    run(%(
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys += key
          @values += value
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
      custom.keys * custom.values
      )).to_i.should eq(90)
  end

  it "creates custom generic hash via alias (2)" do
    run(%(
      class Custom(K, V)
        def initialize
          @keys = 0
          @values = 0
        end

        def []=(key, value)
          @keys += key
          @values += value
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
      custom.keys * custom.values
      )).to_i.should eq(90)
  end
end
