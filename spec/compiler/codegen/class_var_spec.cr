require "../../spec_helper"

describe "Codegen: class var" do
  it "codegens class var" do
    run("
      class Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "codegens class var as nil" do
    run("
      require \"nil\"

      class Foo
        def self.foo
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i.should eq(0)
  end

  it "codegens class var inside instance method" do
    run("
      class Foo
        @@foo = 1

        def foo
          @@foo
        end
      end

      Foo.new.foo
      ").to_i.should eq(1)
  end

  it "codegens class var as nil if assigned for the first time inside method" do
    run("
      require \"nil\"

      class Foo
        def self.foo
          @@foo = 1
          @@foo
        end
      end

      Foo.foo.to_i
      ").to_i.should eq(1)
  end

  it "codegens class var of program" do
    run("
      @@foo = 1
      @@foo
      ").to_i.should eq(1)
  end

  it "codegens class var of program as nil" do
    run("
      require \"nil\"
      @@foo.to_i
      ").to_i.should eq(0)
  end

  it "codegens class var inside module" do
    run("
      module Foo
        @@foo = 1

        def self.foo
          @@foo
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "accesses class var from fun literal" do
    run("
      class Foo
        @@a = 1

        def self.foo
          ->{ @@a }.call
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end
end
