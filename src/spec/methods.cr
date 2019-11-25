module Spec::Methods
  # Defines an example group that describes a unit to be tested.
  # Inside *&block* examples are defined by `#it` or `#pending`.
  #
  # Several `describe` blocks can be nested.
  #
  # Example:
  # ```
  # describe "Int32" do
  #   describe "+" do
  #     it "adds" { (1 + 1).should eq 2 }
  #   end
  # end
  # ```
  #
  # If `focus` is `true`, only this `describe`, and others marked with `focus: true`, will run.
  def describe(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    Spec.root_context.describe(description.to_s, file, line, end_line, focus, tags, &block)
  end

  # Defines an example group that establishes a specific context,
  # like *empty array* versus *array with elements*.
  # Inside *&block* examples are defined by `#it` or `#pending`.
  #
  # It is functionally equivalent to `#describe`.
  #
  # If `focus` is `true`, only this `context`, and others marked with `focus: true`, will run.
  def context(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    describe(description.to_s, file, line, end_line, focus, tags, &block)
  end

  # Defines a concrete test case.
  #
  # The test is performed by the block supplied to *&block*.
  #
  # Example:
  # ```
  # it "adds" { (1 + 1).should eq 2 }
  # ```
  #
  # It is usually used inside a `#describe` or `#context` section.
  #
  # If `focus` is `true`, only this test, and others marked with `focus: true`, will run.
  def it(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    Spec.root_context.it(description.to_s, file, line, end_line, focus, tags, &block)
  end

  # Defines a pending test case.
  #
  # *&block* is never evaluated.
  # It can be used to describe behaviour that is not yet implemented.
  #
  # Example:
  # ```
  # pending "check cat" { cat.alive? }
  # ```
  #
  # It is usually used inside a `#describe` or `#context` section.
  #
  # If `focus` is `true`, only this test, and others marked with `focus: true`, will run.
  def pending(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    pending(description, file, line, end_line, focus, tags)
  end

  # Defines a yet-to-be-implemented pending test case
  #
  # If `focus` is `true`, only this test, and others marked with `focus: true`, will run.
  def pending(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil)
    Spec.root_context.pending(description.to_s, file, line, end_line, focus, tags)
  end

  # DEPRECATED: Use `#it`
  def assert(file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    {{ raise "'assert' was removed: use 'it' instead".id }}
  end

  # Fails an example.
  #
  # This method can be used to manually fail an example defined in an `#it` block.
  def fail(msg, file = __FILE__, line = __LINE__)
    raise Spec::AssertionFailed.new(msg, file, line)
  end

  # Executes the given block before each spec runs.
  def before_each(&block)
    Spec.root_context.before_each(&block)
  end

  # Executes the given block after each spec runs.
  def after_each(&block)
    Spec.root_context.after_each(&block)
  end

  # Executes the given block before all specs in a given
  # `description` or `context` run.
  def before_all(&block)
    Spec.root_context.before_all(&block)
  end

  # Executes the given block after all specs in a given
  # `description` or `context` run.
  def after_all(&block)
    Spec.root_context.after_all(&block)
  end

  # Executes the given block when each spec runs.
  #
  # The block must call `run` on the given `Example::Procsy`
  # object.
  #
  # For example:
  #
  # ```
  # require "spec"
  #
  # describe "something" do
  #   around_each do |example|
  #     puts "before example runs"
  #     example.run
  #     puts "after example runs"
  #   end
  #
  #   it "tests something" do
  #     # ...
  #   end
  # end
  # ```
  def around_each(&block : Example::Procsy ->)
    Spec.root_context.around_each(&block)
  end

  # Executes the given block when each `describe` or `context` runs.
  #
  # The block must call `run` on the given `Context::Procsy`
  # object.
  #
  # For example:
  #
  # ```
  # require "spec"
  #
  # describe "something" do
  #   around_all do |context|
  #     puts "before describe runs"
  #     example.run
  #     puts "after describe runs"
  #   end
  #
  #   it "tests something" do
  #     # ...
  #   end
  # end
  # ```
  def around_all(&block : ExampleGroup::Procsy ->)
    Spec.root_context.around_all(&block)
  end
end

include Spec::Methods
