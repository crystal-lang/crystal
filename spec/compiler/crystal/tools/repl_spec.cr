require "../../../spec_helper"

private def success_value(result) : Crystal::Repl::Value
  success_result = result.should be_a(Crystal::Repl::EvalSuccess)
  success_result.warnings.infos.should be_empty
  success_result.value
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
end
