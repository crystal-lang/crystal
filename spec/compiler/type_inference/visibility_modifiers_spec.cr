#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Visibility modifiers" do
  it "disallows invoking private method" do
    assert_error %(
      class Foo
        private def foo
          1
        end
      end

      Foo.new.foo
      ),
      "private method 'foo' called for Foo"
  end

  it "allows setting visibility modifier to macro" do
    assert_error %(
      class Object
        macro x
          def foo
          end
        end
      end

      class Foo
        private x
      end

      Foo.new.foo
      ),
      "private method 'foo' called for Foo"
  end

  it "allows setting visibility modifier to macro that generates many methods" do
    assert_error %(
      class Object
        macro x
          def foo
          end

          def bar
          end
        end
      end

      class Foo
        private x
      end

      Foo.new.bar
      ),
      "private method 'bar' called for Foo"
  end
end
