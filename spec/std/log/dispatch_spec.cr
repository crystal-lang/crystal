require "spec"
require "log"
require "../../support/retry"

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
