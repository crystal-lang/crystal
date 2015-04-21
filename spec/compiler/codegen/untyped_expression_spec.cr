require "../../spec_helper"

describe "Code gen: untyped expression spec" do
  it "raises if class was never instantiated" do
    expect(run(%(
      require "prelude"

      class Foo
        def foo
          1
        end
      end

      pointer = Pointer(Foo).malloc(1_64)
      foo = pointer.value

      begin
        foo.foo
        false
      rescue ex
        ex.message.includes?("Foo in `foo` was never instantiated")
      end
      )).to_b).to be_true
  end
end
