require "../../spec_helper"

describe "Code gen: regex literal spec" do
  it "works in a class variable (#10951)" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"
      class Foo
        @@regex = /whatever/

        def self.check_regex
          @@regex == /whatever/
        end
      end
      Foo.check_regex
      CRYSTAL
  end
end
