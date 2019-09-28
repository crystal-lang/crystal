require "../../spec_helper"

describe "Semantic: fun" do
  it "errors if defining class inside fun through macro (#6874)" do
    assert_error %(
        macro m
          class Foo
          end
        end

        fun foo
          m
        end
      ),
      "can't define class inside fun"
  end
end
