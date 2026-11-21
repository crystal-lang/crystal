require "spec"
require "log"
require "../../support/retry"

private class FailingBackend < Log::Backend
  getter messages = [] of String

  def write(entry : Log::Entry)
    raise IO::Error.new("write failed") if entry.message == "fail"
    messages << entry.message
  end
end

class Log
  describe Dispatcher do
    it "create dispatcher from enum" do
      Dispatcher.for(:direct).should eq(DirectDispatcher)
      Dispatcher.for(:async).should be_a(AsyncDispatcher)
      Dispatcher.for(:sync).should be_a(SyncDispatcher)
    end
  end

  describe DirectDispatcher do
    it "dispatches entry" do
      backend = Log::MemoryBackend.new
      backend.dispatcher = DirectDispatcher
      backend.dispatch Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      backend.entries.size.should eq(1)
    end
  end

  describe SyncDispatcher do
    it "dispatches entry" do
      backend = Log::MemoryBackend.new
      backend.dispatcher = SyncDispatcher.new
      backend.dispatch Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      backend.entries.size.should eq(1)
    end
  end

  describe AsyncDispatcher do
    it "dispatches entry" do
      backend = Log::MemoryBackend.new
      backend.dispatcher = AsyncDispatcher.new
      backend.dispatch Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      retry { backend.entries.size.should eq(1) }
    end

    it "wait for entries to flush before closing" do
      backend = Log::MemoryBackend.new
      backend.dispatcher = AsyncDispatcher.new
      backend.dispatch Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      backend.close
      backend.entries.size.should eq(1)
    end

    it "keeps dispatching after a backend raises" do
      backend = FailingBackend.new(AsyncDispatcher.new(buffer_size: 1))
      backend.dispatch Entry.new("source", :info, "fail", Log::Metadata.empty, nil)
      3.times { |i| backend.dispatch Entry.new("source", :info, "message #{i}", Log::Metadata.empty, nil) }
      backend.close
      backend.messages.should eq(["message 0", "message 1", "message 2"])
    end

    it "can be closed twice" do
      backend = Log::MemoryBackend.new
      backend.dispatcher = AsyncDispatcher.new
      backend.dispatch Entry.new("source", :info, "message", Log::Metadata.empty, nil)
      backend.close
      backend.close
      backend.entries.size.should eq(1)
    end
  end
end
