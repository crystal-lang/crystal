{% skip_file if flag?(:without_interpreter) %}

require "../../../spec_helper"

private def success_value(result : Crystal::Repl::EvalResult) : Crystal::Repl::Value
  result.warnings.infos.should be_empty
  result.value.should_not be_nil
end

describe Crystal::Repl do
  it "can parse and evaluate snippets" do
    repl = Crystal::Repl.new
    repl.prelude = "primitives"
    repl.load_prelude

    success_value(repl.parse_and_interpret("1 + 2")).value.should eq(3)
    success_value(repl.parse_and_interpret("def foo; 1 + 2; end")).value.should eq(nil)
    success_value(repl.parse_and_interpret("foo")).value.should eq(3)
  end

  describe "can return static and runtime type information for" do
    it "Non Union" do
      repl = Crystal::Repl.new
      repl.prelude = "primitives"
      repl.load_prelude

      repl_value = success_value(repl.parse_and_interpret("1"))
      repl_value.type.to_s.should eq("Int32")
      repl_value.runtime_type.to_s.should eq("Int32")
    end

    it "MixedUnionType" do
      repl = Crystal::Repl.new
      repl.prelude = "primitives"
      repl.load_prelude

      repl_value = success_value(repl.parse_and_interpret("1 || \"a\""))
      repl_value.type.to_s.should eq("(Int32 | String)")
      repl_value.runtime_type.to_s.should eq("Int32")
    end

    it "UnionType" do
      repl = Crystal::Repl.new
      repl.prelude = "primitives"
      repl.load_prelude

      repl_value = success_value(repl.parse_and_interpret("true || 1"))
      repl_value.type.to_s.should eq("(Bool | Int32)")
      repl_value.runtime_type.to_s.should eq("Bool")
    end

    it "VirtualType" do
      repl = Crystal::Repl.new
      repl.prelude = "primitives"
      repl.load_prelude

      repl.parse_and_interpret <<-CRYSTAL
        class Foo
        end

        class Bar < Foo
        end
      CRYSTAL
      repl_value = success_value(repl.parse_and_interpret("Bar.new || Foo.new"))
      repl_value.type.to_s.should eq("Foo+") # Maybe should Foo to match typeof
      repl_value.runtime_type.to_s.should eq("Bar")
    end
  end
end
