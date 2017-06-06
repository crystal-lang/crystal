require "spec"

def should_be_some(subject, expected)
  subject.some?.should eq(true)
  subject.none?.should eq(false)
  subject.value.should eq(expected)
end

def should_be_none(subject)
  subject.some?.should eq(false)
  subject.none?.should eq(true)
  subject.value.nil?.should eq(true)
end

describe "Optional" do
  context "construction" do
    it "creates a some from a value" do
      expected = 42
      subject = Optional.new(expected)
      should_be_some(subject, expected)
    end

    it "creates a some via factory from a value" do
      expected = 42
      subject = Optional.some(expected)
      should_be_some(subject, expected)
    end

    it "creates a none when given no arguments" do
      subject = Optional(Int32).new
      should_be_none(subject)
    end

    it "creates a none when given nil" do
      subject = Optional(Int32).new(nil)
      should_be_none(subject)
    end

    it "creates a none via factory" do
      subject = Optional(Int32).none
      should_be_none(subject)
    end

    it "creates a some when given a block that returns a value" do
      expected = 42
      subject = Optional(Int32).new { expected }
      should_be_some(subject, expected)
    end

    it "creates a none when given a block that returns nil" do
      subject = Optional(Int32).new { nil }
      should_be_none(subject)
    end
  end

  context "#value" do
    it "returns the value when some" do
      expected = 42
      subject = Optional.new(expected)
      subject.value.should eq(expected)
    end

    it "returns nil when none" do
      subject = Optional(Int32).new
      subject.value.nil?.should eq(true)
    end
  end

  context "#value_or" do
    it "returns the value when some and given a value" do
      expected = 42
      subject = Optional.new(42)
      subject.value_or(0).should eq(expected)
    end

    it "returns the value when some and given a block" do
      expected = 42
      subject = Optional.new(42)
      actual = subject.value_or { 0 }
      actual.should eq(expected)
    end

    it "returns the other when none and given a value" do
      expected = 42
      subject = Optional(Int32).new
      subject.value_or(expected).should eq(expected)
    end

    it "returns the other when none and given a block" do
      expected = 42
      subject = Optional(Int32).new
      actual = subject.value_or { expected }
      actual.should eq(expected)
    end
  end

  context "#if_value" do
    it "calls the block with the value when some" do
      expected = 42
      subject = Optional.new(expected)
      actual = 0
      subject.if_value do |value|
        actual = value
      end
      actual.should eq(expected)
    end

    it "does not call the block when none" do
      actual = false
      subject = Optional(Int32).none
      subject.if_value do |value|
        actual = true
      end
      actual.should eq(false)
    end
  end

  context "changing state" do
    it "sets a new value on a some" do
      expected = 42
      subject = Optional.new(0)
      subject.set(42)
      should_be_some(subject, expected)
    end

    it "sets a new value on a none" do
      expected = 42
      subject = Optional(Int32).new
      subject.set(42)
      should_be_some(subject, expected)
    end

    it "sets a new value on a some when given a block" do
      expected = 42
      subject = Optional.new(0)
      subject.set { 42 }
      should_be_some(subject, expected)
    end

    it "sets a new value on a none when given a block" do
      expected = 42
      subject = Optional(Int32).new
      subject.set { 42 }
      should_be_some(subject, expected)
    end

    it "resets the value on a some" do
      subject = Optional.new(42)
      subject.reset
      should_be_none(subject)
    end

    it "resets the value on a none" do
      subject = Optional(Int32).new
      subject.reset
      should_be_none(subject)
    end

    it "applies the block when some and updates the value" do
      expected = 42
      subject = Optional.new(10)
      subject.apply { |current| current + 32 }
      subject.value.should eq(expected)
      should_be_some(subject, expected)
    end

    it "does not apply the block when none" do
      subject = Optional(Int32).new
      actual = subject.apply { |current| current + 32 }
      actual.nil?.should eq(true)
      should_be_none(subject)
    end

    it "swaps the values when both are some" do
      first_value = 42
      second_value = 111
      first_subject = Optional.new(first_value)
      second_subject = Optional.new(second_value)
      first_subject.swap(second_subject)
      should_be_some(first_subject, second_value)
      should_be_some(second_subject, first_value)
    end

    it "swaps the values when some and other is none" do
      first_value = 42
      first_subject = Optional.new(first_value)
      second_subject = Optional(Int32).new
      first_subject.swap(second_subject)
      should_be_none(first_subject)
      should_be_some(second_subject, first_value)
    end

    it "swaps the values when none and other is some" do
      second_value = 111
      first_subject = Optional(Int32).new
      second_subject = Optional.new(second_value)
      first_subject.swap(second_subject)
      should_be_some(first_subject, second_value)
      should_be_none(second_subject)
    end

    it "swaps nothing when both are none" do
      first_subject = Optional(Int32).new
      second_subject = Optional(Int32).new
      first_subject.swap(second_subject)
      should_be_none(first_subject)
      should_be_none(second_subject)
    end
  end

  context "comparisons" do
    it "is not equal when both are none" do
      first = Optional(Int32).new
      second = Optional(Int32).new
      actual = (first <=> second)
      actual.should_not eq(0)
    end

    it "is not equal when some and other is none" do
      first = Optional(Int32).new(42)
      second = Optional(Int32).new
      actual = (first <=> second)
      actual.should_not eq(0)
    end

    it "is not equal when none and other is some" do
      first = Optional(Int32).new
      second = Optional(Int32).new(42)
      actual = (first <=> second)
      actual.should_not eq(0)
    end

    it "is equal when both are some with same value" do
      first = Optional(Int32).new(42)
      second = Optional(Int32).new(42)
      actual = (first <=> second)
      actual.should eq(0)
    end

    it "is not equal when both are some with different value" do
      first = Optional(Int32).new(21)
      second = Optional(Int32).new(42)
      actual = (first <=> second)
      actual.should_not eq(0)
    end

    it "is not equal to a value when none" do
      other = 42
      subject = Optional(Int32).new
      actual = (subject <=> other)
      actual.should_not eq(0)
    end

    it "is not equal to a different value when some" do
      other = 42
      subject = Optional(Int32).new(111)
      actual = (subject <=> other)
      actual.should_not eq(0)
    end

    it "is equal to its own value when some" do
      other = 42
      subject = Optional(Int32).new(other)
      actual = (subject <=> other)
      actual.should eq(0)
    end
  end
end
