require "../../spec_helper"

describe "Semantic: fun" do
  it "errors if defining class inside fun through macro (#6874)" do
    assert_error <<-CRYSTAL, "can't define class inside fun"
      macro m
        class Foo
        end
      end

      fun foo
        m
      end
      CRYSTAL
  end
end
