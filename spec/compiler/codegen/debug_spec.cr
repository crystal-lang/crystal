require "../../spec_helper"

describe "Code gen: debug" do
  it "codegens abstract struct (#3578)" do
    codegen(%(
      abstract struct Base
      end

      struct Foo < Base
      end

      struct Bar < Base
      end

      x = Foo.new || Bar.new
      ), debug: true)
  end
end
