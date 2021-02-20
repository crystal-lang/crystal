require "../../spec_helper"

describe "Code gen: array literal spec" do
  it "creates custom non-generic array" do
    run(%(
      class Custom
        def initialize
          @value = 0
        end

        def <<(element)
          @value &+= element
        end

        def value
          @value
        end
      end

      custom = Custom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom generic array" do
    run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value &+= element
        end

        def value
          @value
        end
      end

      custom = Custom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom generic array with type var" do
    run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value &+= element
        end

        def value
          @value
        end
      end

      custom = Custom(Int32) {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom generic array via alias" do
    run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value &+= element
        end

        def value
          @value
        end
      end

      alias MyCustom = Custom

      custom = MyCustom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom generic array via alias (2)" do
    run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value &+= element
        end

        def value
          @value
        end
      end

      alias MyCustom = Custom(Int32)

      custom = MyCustom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom non-generic array in nested module" do
    run(%(
      class Foo::Custom
        def initialize
          @value = 0
        end

        def <<(element)
          @value &+= element
        end

        def value
          @value
        end
      end

      custom = Foo::Custom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom non-generic array in module" do
    run(%(
      module Moo
        class Custom
          def initialize
            @value = 0
          end

          def <<(element)
            @value &+= element
          end

          def value
            @value
          end
        end
      end

      custom = Moo::Custom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates custom generic array in module (#5684)" do
    run(%(
      module Moo
        class Custom(T)
          def initialize
            @value = 0
          end

          def <<(element : T)
            @value &+= element
          end

          def value
            @value
          end
        end
      end

      custom = Moo::Custom {1, 2, 3}
      custom.value
      )).to_i.should eq(6)
  end

  it "creates typed array" do
    run("require \"prelude\"; typeof([1, 2] of Int8)").to_string.should eq("Array(Int8)")
  end

  it "assignment in array literal works" do
    run("require \"prelude\"; [a = 1]; a").to_i.should eq(1)
  end

  it "assignment in array-like literal works" do
    run("require \"prelude\"; Array(Int32){a = 1}; a").to_i.should eq(1)
  end
end
