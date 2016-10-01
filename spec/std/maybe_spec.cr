require "spec"

def should_be_succeeded(subject, expected)
  subject.succeeded?.should eq(true)
  subject.failed?.should eq(false)
  subject.result.should eq(expected)
  subject.failure.nil?.should eq(true)
  subject.message.empty?.should eq(true)
end

def should_be_failed(subject, ex : Exception)
  subject.succeeded?.should eq(false)
  subject.failed?.should eq(true)
  subject.result.nil?.should eq(true)
  subject.failure.should eq(ex)
  subject.message.should eq(ex.to_s)
end

def should_be_failed(subject, msg : String)
  subject.succeeded?.should eq(false)
  subject.failed?.should eq(true)
  subject.result.nil?.should eq(true)
  subject.failure.class.should eq(Exception)
  subject.message.should eq(msg)
end

describe "Maybe" do
  context "construction" do
    it "is succeeded when the block returns" do
      expected = 42
      subject = Maybe(Int32).new { expected }
      should_be_succeeded(subject, expected)
    end

    it "is failed when the block raises an exception" do
      ex = Exception.new("Boom!")
      subject = Maybe(Int32).new { raise ex }
      should_be_failed(subject, ex)
    end

    it "is successful when created by the factory" do
      expected = 42
      subject = Maybe.succeed(expected)
      should_be_succeeded(subject, expected)
    end

    it "is failed when created by the exception factory" do
      ex = Exception.new("Boom!")
      subject = Maybe(Int32).fail(ex)
      should_be_failed(subject, ex)
    end

    it "is failed when created by the message factory" do
      message = "Boom!"
      subject = Maybe(Int32).fail(message)
      should_be_failed(subject, message)
    end
  end

  context "result_or" do
    it "returns the result when successful" do
      expected = 42
      subject = Maybe.succeed(expected)
      actual = subject.result_or(0)
      expected.should eq(actual)
    end

    it "returns the given value when failed" do
      expected = 42
      subject = Maybe(Int32).fail("Boom!")
      actual = subject.result_or(expected)
      expected.should eq(actual)
    end

    it "returns the result of the block when successful" do
      expected = 42
      subject = Maybe(Int32).new { expected }
      actual = subject.result_or(0)
      expected.should eq(actual)
    end

    it "returns the given value when the block raises an exception" do
      expected = 42
      subject = Maybe(Int32).new { raise "Boom!" }
      actual = subject.result_or(expected)
      expected.should eq(actual)
    end
  end
end
