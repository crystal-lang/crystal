require "spec"
require "log"

private def s(value : Log::Severity)
  value
end

describe Log::BroadcastBackend do
  it "writes to the backend based on level" do
    main = Log::BroadcastBackend.new
    backend_a = Log::MemoryBackend.new
    backend_b = Log::MemoryBackend.new

    main.append(backend_a, s(:info))
    main.append(backend_b, s(:error))

    debug_entry = Log::Entry.new("", s(:debug), "", Log::Metadata.empty, nil)
    info_entry = Log::Entry.new("", s(:info), "", Log::Metadata.empty, nil)
    error_entry = Log::Entry.new("", s(:error), "", Log::Metadata.empty, nil)

    main.write debug_entry
    main.write info_entry
    main.write error_entry

    backend_a.entries.should eq([info_entry, error_entry])
    backend_b.entries.should eq([error_entry])
  end

  it "overwriting log level overwrites to all backends" do
    main = Log::BroadcastBackend.new
    backend_a = Log::MemoryBackend.new
    backend_b = Log::MemoryBackend.new

    main.append(backend_a, s(:info))
    main.append(backend_b, s(:error))

    log = Log.new("", main, s(:info))
    log.level = s(:info)

    log.info { "lorem" }

    backend_a.entries.should_not be_empty
    backend_b.entries.should_not be_empty

    backend_a.entries.clear
    backend_b.entries.clear

    log.debug { "lorem" }

    backend_a.entries.should be_empty
    backend_b.entries.should be_empty

    backend_a.entries.clear
    backend_b.entries.clear

    main.level = nil
    log.info { "lorem" }

    backend_a.entries.should_not be_empty
    backend_b.entries.should be_empty
  end

  describe "#min_level" do
    it "on empty" do
      main = Log::BroadcastBackend.new
      main.min_level.should eq(s(:none))
    end

    it "single backend" do
      main = Log::BroadcastBackend.new
      main.append(Log::MemoryBackend.new, s(:warn))

      main.min_level.should eq(s(:warn))
    end

    it "multiple backends" do
      main = Log::BroadcastBackend.new
      main.append(Log::MemoryBackend.new, s(:info))
      main.append(Log::MemoryBackend.new, s(:warn))

      main.min_level.should eq(s(:info))
    end
  end
end
