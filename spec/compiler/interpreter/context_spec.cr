{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

private def put_strings(stack : UInt8*, count : Int32) : Nil
  count.times do |i|
    stack.as(String*)[i] = "string #{i}"
  end
end

describe Crystal::Repl::Context do
  it "keeps objects referenced only from a checked out stack alive" do
    context = Crystal::Repl::Context.new(Crystal::Program.new)
    context.checkout_stack do |stack|
      put_strings(stack, 100)
      GC.collect
      10_000.times { |i| "garbage #{i}" }

      100.times do |i|
        stack.as(String*)[i].should eq("string #{i}")
      end
    end
  end
end
