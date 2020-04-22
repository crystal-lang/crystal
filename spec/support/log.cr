require "log"

def capture_logs(source, level : Log::Severity = :debug)
  log = Log.for(source)
  old_backend = log.backend
  old_level = log.level
  log.backend = mem_backend = Log::MemoryBackend.new
  log.level = level
  begin
    yield mem_backend.entries
    mem_backend.entries
  ensure
    log.backend = old_backend
    log.level = old_level
  end
end

def match_logs(logs, *log_specs : {Symbol, String | Regex} | {Symbol, String | Regex, Exception})
  logs.size.should eq(log_specs.size)
  logs.zip(log_specs) do |log, spec|
    log.severity.to_s.downcase.should eq(spec[0].to_s.downcase)
    case msg_spec = spec[1]
    when String
      log.message.should eq(msg_spec)
    when Regex
      log.message.should match(msg_spec)
    end

    if spec.size > 2
      log.exception.should eq(spec[2]?)
    end
  end
end
