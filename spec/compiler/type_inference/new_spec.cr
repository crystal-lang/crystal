require "../../spec_helper"

describe "Type inference: new" do
  it "doesn't incorrectly redefines new for generic class" do
    assert_type(%(
      class Foo(T)
        def self.new
          1
        end
      end

      Foo(Int32).new
      )) { int32 }
  end
end
