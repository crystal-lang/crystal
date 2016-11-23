module Spec::DSL
  def describe(description, file = __FILE__, line = __LINE__, &block)
    Spec::RootContext.describe(description.to_s, file, line, &block)
  end

  def context(description, file = __FILE__, line = __LINE__, &block)
    describe(description.to_s, file, line, &block)
  end

  def it(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    return unless Spec.matches?(description, file, line, end_line)

    Spec.formatters.each(&.before_example(description))

    start = Time.now
    begin
      Spec.run_before_each_hooks
      block.call
      Spec::RootContext.report(:success, description, file, line, Time.now - start)
    rescue ex : Spec::AssertionFailed
      Spec::RootContext.report(:fail, description, file, line, Time.now - start, ex)
      Spec.abort! if Spec.fail_fast?
    rescue ex
      Spec::RootContext.report(:error, description, file, line, Time.now - start, ex)
      Spec.abort! if Spec.fail_fast?
    ensure
      Spec.run_after_each_hooks
    end
  end

  def pending(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    return unless Spec.matches?(description, file, line, end_line)

    Spec.formatters.each(&.before_example(description))

    Spec::RootContext.report(:pending, description, file, line)
  end

  def assert(file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    it("assert", file, line, end_line, &block)
  end

  def fail(msg, file = __FILE__, line = __LINE__)
    raise Spec::AssertionFailed.new(msg, file, line)
  end
end

include Spec::DSL
