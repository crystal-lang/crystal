require "../../spec_helper"

describe "Code gen: regex literal spec" do
  it "works in a class variable (#10951)" do
    run(%(
      require "prelude"
      class Foo
        @@regex = /whatever/

        def self.check_regex
          @@regex == /whatever/
        end
      end
      Foo.check_regex
      )).to_b.should eq(true)
  end
end
