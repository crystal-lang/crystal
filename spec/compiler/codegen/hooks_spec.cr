require "../../spec_helper"

describe "Code gen: hooks" do
  it "does inherited macro" do
    run("
      class Foo
        macro inherited
          $x = 1
        end
      end

      class Bar < Foo
      end

      $x
      ").to_i.should eq(1)
  end

  it "does included macro" do
    run("
      module Foo
        macro included
          $x = 1
        end
      end

      class Bar
        include Foo
      end

      $x
      ").to_i.should eq(1)
  end

  it "does extended macro" do
    run("
      module Foo
        macro extended
          $x = 1
        end
      end

      class Bar
        extend Foo
      end

      $x
      ").to_i.should eq(1)
  end

  it "does inherited macro recursively" do
    run("
      $x = 0
      class Foo
        macro inherited
          $x += 1
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      $x
      ").to_i.should eq(2)
  end
end
