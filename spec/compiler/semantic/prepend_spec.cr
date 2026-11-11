require "../../spec_helper"

describe "Semantic: prepend" do
  it "registers the prepended module on the type and surfaces it through the macro `ancestors`" do
    result = semantic(<<-CRYSTAL)
      module Prepended
      end

      class Subclass
        prepend Prepended

        def foo
          1
        end
      end
      CRYSTAL

    subclass = result.program.types["Subclass"].as(Crystal::ModuleType)
    subclass.prepended_modules.try(&.map(&.to_s)).should eq(["Prepended"])
    subclass.ancestors_with_prepended.map(&.to_s).first.should eq("Prepended")
  end

  it "method call on instance resolves to prepended module's def" do
    assert_type(<<-CRYSTAL) { int32 }
      module Prepended
        def foo
          1
        end
      end

      class Subclass
        prepend Prepended

        def foo
          'a'
        end
      end

      Subclass.new.foo
      CRYSTAL
  end

  it "errors with cyclic prepend" do
    assert_error <<-CRYSTAL, "cyclic prepend detected"
      module Foo
      end

      module Bar
        prepend Foo
      end

      module Foo
        prepend Bar
      end
      CRYSTAL
  end

  it "errors when prepending self" do
    assert_error <<-CRYSTAL, "cyclic prepend detected"
      module Foo
        prepend self
      end
      CRYSTAL
  end

  it "rejects prepend of a non-module" do
    assert_error <<-CRYSTAL, "is not a module, it's a class"
      class Foo
      end

      class Bar
        prepend Foo
      end
      CRYSTAL
  end
end
