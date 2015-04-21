require "../../spec_helper"

describe "Code gen: array literal spec" do
  it "creates custom non-generic array" do
    expect(run(%(
      class Custom
        def initialize
          @value = 0
        end

        def <<(element)
          @value += element
        end

        def value
          @value
        end
      end

      custom = Custom {1, 2, 3}
      custom.value
      )).to_i).to eq(6)
  end

  it "creates custom generic array" do
    expect(run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value += element
        end

        def value
          @value
        end
      end

      custom = Custom {1, 2, 3}
      custom.value
      )).to_i).to eq(6)
  end

  it "creates custom generic array with type var" do
    expect(run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value += element
        end

        def value
          @value
        end
      end

      custom = Custom(Int32) {1, 2, 3}
      custom.value
      )).to_i).to eq(6)
  end

  it "creates custom generic array via alias" do
    expect(run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value += element
        end

        def value
          @value
        end
      end

      alias MyCustom = Custom

      custom = MyCustom {1, 2, 3}
      custom.value
      )).to_i).to eq(6)
  end

  it "creates custom generic array via alias (2)" do
    expect(run(%(
      class Custom(T)
        def initialize
          @value = 0
        end

        def <<(element : T)
          @value += element
        end

        def value
          @value
        end
      end

      alias MyCustom = Custom(Int32)

      custom = MyCustom {1, 2, 3}
      custom.value
      )).to_i).to eq(6)
  end

  it "creates custom non-generic array in nested module" do
    expect(run(%(
      class Foo::Custom
        def initialize
          @value = 0
        end

        def <<(element)
          @value += element
        end

        def value
          @value
        end
      end

      custom = Foo::Custom {1, 2, 3}
      custom.value
      )).to_i).to eq(6)
  end
end
