require "../../spec_helper"

describe "Codegen: private" do
  it "codegens private def in same file" do
    compile(<<-CRYSTAL)
      private def foo
        1
      end

      foo
      CRYSTAL
  end

  it "codegens overloaded private def in same file" do
    compile(<<-CRYSTAL)
      private def foo(x : Int32)
        1
      end

      private def foo(x : Char)
        2
      end

      a = 3 || 'a'
      foo a
      CRYSTAL
  end

  it "codegens private def reading self in same file" do
    compile(<<-CRYSTAL)
      private def foo
        d = self
      end

      foo
      CRYSTAL
  end

  it "codegens class var of private type with same name as public type (#11620)" do
    compile(<<-CRYSTAL, <<-CRYSTAL)
      module Foo
        @@x = true
      end
    CRYSTAL
      private module Foo
        @@x = 1
      end
    CRYSTAL
  end

  it "codegens class vars of private types with same name (#11620)" do
    compile(<<-CRYSTAL, <<-CRYSTAL)
      private module Foo
        @@x = true
      end
    CRYSTAL
      private module Foo
        @@x = 1
      end
    CRYSTAL
  end

  it "doesn't include filename for private types" do
    run(<<-CRYSTAL, filename: "foo").to_string.should eq("Foo")
      private class Foo
        def foo
          {{@type.stringify}}
        end
      end

      Foo.new.foo
      CRYSTAL
  end
end
