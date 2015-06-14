module Spec::DSL
  def describe(description, file = __FILE__, line = __LINE__)
    Spec::RootContext.describe(description.to_s, file, line) do |context|
      yield
    end
  end

  def context(description, file = __FILE__, line = __LINE__)
    describe(description.to_s, file, line) { |ctx| yield ctx }
  end

  def it(description, file = __FILE__, line = __LINE__)
    return if Spec.aborted?
    return unless Spec.matches?(description, file, line)

    Spec.formatter.before_example description

    begin
      Spec.run_before_each_hooks
      yield
      Spec::RootContext.report(:success, description, file, line)
    rescue ex : Spec::AssertionFailed
      Spec::RootContext.report(:fail, description, file, line, ex)
      Spec.abort! if Spec.fail_fast?
    rescue ex
      Spec::RootContext.report(:error, description, file, line, ex)
      Spec.abort! if Spec.fail_fast?
    ensure
      Spec.run_after_each_hooks
    end
  end

  def pending(description, file = __FILE__, line = __LINE__, &block)
    return if Spec.aborted?
    return unless Spec.matches?(description, file, line)

    Spec.formatter.before_example description

    Spec::RootContext.report(:pending, description, file, line)
  end

  def assert(file = __FILE__, line = __LINE__)
    it("assert", file, line) { yield }
  end

  def fail(msg, file = __FILE__, line = __LINE__)
    raise Spec::AssertionFailed.new(msg, file, line)
  end
end

include Spec::DSL
