require "spec"

private module MyModule; end

private class Foo
  include MyModule
end

private record NoObjectId, to_unsafe : Int32 do
  def same?(other : self) : Bool
    to_unsafe == other.to_unsafe
  end
end

private class ExceptionWithOverriddenToS < Exception
  def initialize(message : String, @to_s : String)
    super(message)
  end

  def to_s
    @to_s
  end
end

describe "expectations" do
  describe "accept a custom failure message" do
    it { 1.should be < 3, "custom message!" }
    it do
      expect_raises(Spec::AssertionFailed, "custom message!") do
        1.should_not be < 3, "custom message!"
      end
    end
  end

  describe "be" do
    it { 1.should be < 3 }
    it { 2.should be <= 3 }
    it { 3.should be <= 3 }
    it { 3.should be >= 3 }
    it { 4.should be >= 3 }
    it { 5.should be > 3 }
  end

  describe "be" do
    it { "hello".should be "hello" }
    it do
      array = [1]
      array.should_not be [1]
    end

    it "works with type that does not implement `#object_id`" do
      a = NoObjectId.new(1)
      a.should be a
      a.should_not be NoObjectId.new(2)
    end

    it "works with module type (#14920)" do
      a = Foo.new
      a.as(MyModule).should be a.as(MyModule)
    end
  end

  describe "be_a" do
    it { "Hello".should be_a(String) }
    it { 100_000.should_not be_a(String) }
    it { 100_000.should be_a(Int32) }
    it { "Hello".should_not be_a(Int32) }

    it "restricts type on should" do
      x = 1 || 'a'
      y = x.should be_a(Int32)
      typeof(x).should eq(Int32 | Char)
      typeof(y).should eq(Int32)
    end

    it "restricts type on should_not" do
      x = 1 || 'a'
      y = x.should_not be_a(Char)
      typeof(x).should eq(Int32 | Char)
      typeof(y).should eq(Int32)
    end
  end

  describe "be_close" do
    it { 8.5.should be_close(9, 0.5) }
    it { 7.5.should_not be_close(9, 0.5) }
  end

  describe "be_nil" do
    it { nil.should be_nil }
    it { "".should_not be_nil }
    it { 10.should_not be_nil }

    it "restricts type on should_not" do
      x = 1 || nil
      y = x.should_not be_nil
      typeof(x).should eq(Int32?)
      typeof(y).should eq(Int32)
    end
  end

  describe "be_falsey" do
    it { nil.should be_falsey }
    it { false.should be_falsey }
    it { true.should_not be_falsey }
    it { "crystal".should_not be_falsey }
  end

  describe "be_truthy" do
    it { true.should be_truthy }
    it { "crystal".should be_truthy }
    it { nil.should_not be_truthy }
    it { false.should_not be_truthy }
  end

  describe "be_false" do
    it { false.should be_false }
    it { nil.should_not be_false }
    it { true.should_not be_false }
    it { "crystal".should_not be_false }
  end

  describe "be_true" do
    it { true.should be_true }
    it { nil.should_not be_true }
    it { false.should_not be_true }
    it { "crystal".should_not be_true }
  end

  describe "contain" do
    it { [1, 2, 3].should contain(1) }
    it { [1, 2, 3].should contain(2) }
    it { [1, 2, 3].should contain(3) }
    it { [1, 2, 3].should_not contain(4) }
    it { "crystal".should contain("c") }
    it { "crystal".should contain("crys") }
    it { "crystal".should contain("crystal") }
    it { "crystal".should_not contain("o") }
    it { "crystal".should_not contain("world") }
  end

  describe "eq" do
    it { 10.should eq(10) }
    it { 10.should_not eq(1) }
  end

  describe "match" do
    it { "Crystal".should match(/Crystal/) }
    it { "Crystal".should match(/ysta/) }
    it { "Crystal".should_not match(/hello/) }
  end

  describe "start_with" do
    it { "1-2-3".should start_with("") }
    it { "1-2-3".should start_with("1") }
    it { "1-2-3".should start_with("1-") }
    it { "1-2-3".should start_with("1-2-3") }
    it { "1-2-3".should_not start_with("2-") }
    it { "1-2-3".should_not start_with("1-2-3-4") }
  end

  describe "end_with" do
    it { "1-2-3".should end_with("") }
    it { "1-2-3".should end_with("3") }
    it { "1-2-3".should end_with("-3") }
    it { "1-2-3".should end_with("1-2-3") }
    it { "1-2-3".should_not end_with("-2") }
    it { "1-2-3".should_not end_with("0-1-2-3") }
  end

  context "empty" do
    it { "".should be_empty }
    it { Array(String).new.should be_empty }
    it { Hash(String, String).new.should be_empty }
    it { "foo".should_not be_empty }
    it { ["foo", "bar"].should_not be_empty }
    it { {"foo" => "bar"}.should_not be_empty }
    it { {"foo", "bar"}.should_not be_empty }
  end

  describe "expect_raises" do
    it "passes if expected message equals actual message and expected class equals actual class" do
      expect_raises(Exception, "Ops") { raise Exception.new("Ops") }
    end

    it "passes if expected message equals actual message and expected class is an ancestor of actual class" do
      expect_raises(Exception, "Ops") { raise ArgumentError.new("Ops") }
    end

    it "passes if expected message is a substring of actual message and expected class equals actual class" do
      expect_raises(Exception, "Ops") { raise Exception.new("Black Ops") }
    end

    it "passes if expected message is a substring of actual message and expected class is an ancestor of actual class" do
      expect_raises(Exception, "Ops") { raise ArgumentError.new("Black Ops") }
    end

    it "passes if expected regex matches actual message and expected class equals actual class" do
      expect_raises(Exception, /Ops/) { raise Exception.new("Black Ops") }
    end

    it "passes if expected regex matches actual message and expected class is an ancestor of actual class" do
      expect_raises(Exception, /Ops/) { raise ArgumentError.new("Black Ops") }
    end

    it "passes if given no message expectation and expected class equals actual class" do
      expect_raises(Exception) { raise Exception.new("Ops") }
    end

    it "passes if given no message expectation and expected class is an ancestor of actual class" do
      expect_raises(Exception) { raise ArgumentError.new("Ops") }
    end

    it "passes if given no message expectation, actual message is nil and expected class equals actual class" do
      expect_raises(Exception) { raise Exception.new(nil) }
    end

    it "passes if given no message expectation, actual message is nil and expected class is an ancestor of actual class" do
      expect_raises(Exception) { raise ArgumentError.new(nil) }
    end

    it "fails if expected message does not equal actual message and expected class equals actual class" do
      expect_raises(Exception, "Ops") { raise Exception.new("Hm") }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "fails if given expected message, actual message is nil and expected class equals actual class" do
      expect_raises(Exception, "Ops") { raise Exception.new(nil) }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "fails if expected regex does not match actual message and expected class equals actual class" do
      expect_raises(Exception, /Ops/) { raise Exception.new("Hm") }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "fails if given expected regex, actual message is nil and expected class equals actual class" do
      expect_raises(Exception, /Ops/) { raise Exception.new(nil) }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "fails if given no message expectation and expected class does not equal and is not an ancestor of actual class" do
      expect_raises(IndexError) { raise ArgumentError.new("Ops") }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "fails if given no message expectation, actual message is nil and expected class does not equal and is not an ancestor of actual class" do
      expect_raises(IndexError) { raise ArgumentError.new(nil) }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "fails if nothing was raised" do
      expect_raises(IndexError) { raise ArgumentError.new("Ops") }
    rescue Spec::AssertionFailed
      # success
    else
      fail "expected Spec::AssertionFailed but nothing was raised"
    end

    it "uses the exception's #to_s output to match a given String" do
      expect_raises(Exception, "Hm") { raise ExceptionWithOverriddenToS.new("Ops", to_s: "Hm") }
    end

    it "uses the exception's #to_s output to match a given Regex" do
      expect_raises(Exception, /Hm/) { raise ExceptionWithOverriddenToS.new("Ops", to_s: "Hm") }
    end

    describe "failure message format" do
      context "given string to compare with message" do
        it "contains expected exception, actual exception and backtrace" do
          expect_raises(Exception, "digits should be non-negative") do
            raise IndexError.new("Index out of bounds")
          end
        rescue e : Spec::AssertionFailed
          # don't check backtrace items because they are platform specific
          e.message.as(String).should contain(<<-MESSAGE)
            Expected Exception with message containing: "digits should be non-negative"
                 got IndexError with message: "Index out of bounds"
            Backtrace:
            MESSAGE
        else
          fail "expected Spec::AssertionFailed but nothing is raised"
        end

        it "contains expected class, actual exception and backtrace when expected class does not match actual class" do
          expect_raises(ArgumentError, "digits should be non-negative") do
            raise IndexError.new("Index out of bounds")
          end
        rescue e : Spec::AssertionFailed
          # don't check backtrace items because they are platform specific
          e.message.as(String).should contain(<<-MESSAGE)
            Expected ArgumentError
                 got IndexError with message: "Index out of bounds"
            Backtrace:
            MESSAGE
        else
          fail "expected Spec::AssertionFailed but nothing is raised"
        end

        it "escapes expected and actual messages in the same way" do
          expect_raises(Exception, %q(a\tb\nc)) do
            raise %q(a\tb\nc).inspect
          end
        rescue e : Spec::AssertionFailed
          e.message.as(String).should contain("Expected Exception with message containing: #{%q(a\tb\nc).inspect}")
          e.message.as(String).should contain("got Exception with message: #{%q(a\tb\nc).inspect.inspect}")
        else
          fail "expected Spec::AssertionFailed but nothing is raised"
        end
      end

      context "given regex to match a message" do
        it "contains expected exception, actual exception and backtrace" do
          expect_raises(Exception, /digits should be non-negative/) do
            raise IndexError.new("Index out of bounds")
          end
        rescue e : Spec::AssertionFailed
          # don't check backtrace items because they are platform specific
          e.message.as(String).should contain(<<-MESSAGE)
            Expected Exception with message matching: /digits should be non-negative/
                 got IndexError with message: "Index out of bounds"
            Backtrace:
            MESSAGE
        else
          fail "expected Spec::AssertionFailed but nothing is raised"
        end

        it "contains expected class, actual exception and backtrace when expected class does not match actual class" do
          expect_raises(ArgumentError, /digits should be non-negative/) do
            raise IndexError.new("Index out of bounds")
          end
        rescue e : Spec::AssertionFailed
          # don't check backtrace items because they are platform specific
          e.message.as(String).should contain(<<-MESSAGE)
            Expected ArgumentError
                 got IndexError with message: "Index out of bounds"
            Backtrace:
            MESSAGE
        else
          fail "expected Spec::AssertionFailed but nothing is raised"
        end
      end

      context "given nil to allow any message" do
        it "contains expected class, actual exception and backtrace when expected class does not match actual class" do
          expect_raises(ArgumentError, nil) do
            raise IndexError.new("Index out of bounds")
          end
        rescue e : Spec::AssertionFailed
          # don't check backtrace items because they are platform specific
          e.message.as(String).should contain(<<-MESSAGE)
            Expected ArgumentError
                 got IndexError with message: "Index out of bounds"
            Backtrace:
            MESSAGE
        else
          fail "expected Spec::AssertionFailed but nothing is raised"
        end
      end

      context "nothing was raises" do
        it "contains expected class" do
          expect_raises(IndexError) { }
        rescue e : Spec::AssertionFailed
          e.message.as(String).should contain("Expected IndexError but nothing was raised")
        else
          fail "expected Spec::AssertionFailed but nothing was raised"
        end
      end
    end
  end
end
