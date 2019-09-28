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
  def describe(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, &block)
    Spec.root_context.describe(description.to_s, file, line, end_line, focus, &block)
  end

  # Defines an example group that establishes a specific context,
  # like *empty array* versus *array with elements*.
  # Inside *&block* examples are defined by `#it` or `#pending`.
  #
  # It is functionally equivalent to `#describe`.
  #
  # If `focus` is `true`, only this `context`, and others marked with `focus: true`, will run.
  def context(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, &block)
    describe(description.to_s, file, line, end_line, focus, &block)
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
  def it(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, &block)
    Spec.root_context.it(description.to_s, file, line, end_line, focus, &block)
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
  def pending(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, &block)
    pending(description, file, line, end_line, focus)
  end

  # Defines a yet-to-be-implemented pending test case
  #
  # If `focus` is `true`, only this test, and others marked with `focus: true`, will run.
  def pending(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false)
    Spec.root_context.pending(description.to_s, file, line, end_line, focus)
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
end

include Spec::Methods
