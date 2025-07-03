{% skip_file unless flag?(:execution_context) %}
require "spec"

describe Fiber::ExecutionContext::Parallel do
  it ".new" do
    mt = Fiber::ExecutionContext::Parallel.new("test", maximum: 2)
    mt.size.should eq(0)
    mt.capacity.should eq(2)

    expect_raises(ArgumentError, "Parallelism can't be less than one") do
      Fiber::ExecutionContext::Parallel.new("test", maximum: -1)
    end

    expect_raises(ArgumentError, "Parallelism can't be less than one") do
      Fiber::ExecutionContext::Parallel.new("test", maximum: 0)
    end
  end
end
