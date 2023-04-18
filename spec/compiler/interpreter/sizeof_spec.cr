{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "sizeof" do
    it "interprets sizeof typeof" do
      interpret("sizeof(typeof(1))").should eq(4)
    end
  end
end
