require "../../spec_helper"

describe "macro" do
  describe "macro methods" do
    it "checks for correct return type" do
      expect_raises Crystal::TypeException, "Error in line 3: expected 'bar' to return String, not Nil" do
        run("
          class Foo
            macro def self.bar : String
              nil
            end
          end

          Foo.bar
        ")
      end

      run(%{
        class Foo
          macro def self.bar : String
            "foo"
          end
        end

        Foo.bar
      })
    end

    it "allows subclasses of return type" do
      run(%{
        class Foobar
        end

        class Bar < Foobar
        end

        class Foo
          macro def self.bar : Foobar
            Bar.new
          end
        end

        Foo.bar
      })
    end

    it "allows return values that include the return type" do
      run(%{
        module Foobar
        end

        class Bar
          include Foobar
        end

        class Foo
          macro def self.bar : Foobar
            Bar.new
          end
        end

        Foo.bar
      })
    end

    it "allows generic return types" do
      run(%{
        class Bar(T)
          def initialize(@foo : T)
          end
        end

        class Foo
          macro def self.bar : Bar(String)
            Bar.new("foo")
          end
        end

        Foo.bar
      })

      expect_raises Crystal::TypeException do
        run(%{
          class Bar(T)
            def initialize(@foo : T)
            end
          end

          class Foo
            macro def self.bar : Bar(String)
              Bar.new(3)
            end
          end

          Foo.bar
        })
      end
    end

    it "allows union return types" do
      run(%{
        class Foo
          macro def self.bar : String?
            nil
          end
        end

        Foo.bar
      })
    end
  end
end
