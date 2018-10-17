require "spec"

private def assert_cancel(&block : ->)
  exception = nil
  fiber = spawn name: "fiber" do
    block.call
  rescue exc : Fiber::CancelledException
    exception = exc
  end

  Fiber.yield
  fiber.cancel
  Fiber.yield

  exception.should_not be_nil
  exception.not_nil!.fiber.should eq fiber
  exception.not_nil!.message.should eq "Fiber cancelled: #{fiber}"
  cause = exception.not_nil!.cause.not_nil!
  cause.message.should eq "Fiber cancel request"
  cause.fiber.should eq Fiber.current
end

describe Fiber do
  describe "#cancel" do
    context "from other fiber" do
      it "Fiber.yield" do
        assert_cancel { Fiber.yield }
      end
      it "sleep" do
        assert_cancel { sleep }
      end
      it "sleep(1)" do
        assert_cancel { sleep(1) }
      end
    end

    it "from same fiber" do
      exception = nil
      fiber = nil
      fiber = spawn name: "fiber" do
        fiber.not_nil!.cancel
      rescue exc : Fiber::CancelledException
        exception = exc
      end

      Fiber.yield

      exception.should_not be_nil
      exception.not_nil!.fiber.should eq fiber
      exception.not_nil!.message.should eq "Fiber cancelled: #{fiber}"
      exception.not_nil!.cause.should be_nil
    end
  end
end
