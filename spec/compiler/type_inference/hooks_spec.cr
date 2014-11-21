require "../../spec_helper"

describe "Type inference: hooks" do
  it "does inherited macro" do
    assert_type("
      class Foo
        macro inherited
          def self.{{@class_name.downcase.id}}
            1
          end
        end
      end

      class Bar < Foo
      end

      Bar.bar
      ") { int32 }
  end

  it "does included macro" do
    assert_type("
      module Foo
        macro included
          def self.{{@class_name.downcase.id}}
            1
          end
        end
      end

      class Bar
        include Foo
      end

      Bar.bar
      ") { int32 }
  end

  it "does extended macro" do
    assert_type("
      module Foo
        macro extended
          def self.{{@class_name.downcase.id}}
            1
          end
        end
      end

      class Bar
        extend Foo
      end

      Bar.bar
      ") { int32 }
  end

  it "errors if wrong inherited args length" do
    assert_error %(
      class Foo
        macro inherited(x)
        end
      end
      ), "macro 'inherited' must not have arguments"
  end

  it "errors if wrong included args length" do
    assert_error %(
      module Foo
        macro included(x)
        end
      end
      ), "macro 'included' must not have arguments"
  end

  it "errors if wrong extended args length" do
    assert_error %(
      module Foo
        macro extended(x)
        end
      end
      ), "macro 'extended' must not have arguments"
  end
end
