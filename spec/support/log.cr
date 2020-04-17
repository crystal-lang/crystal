def capture_log(source, level : Log::Severity = :info)
  log = Log.for(source)
  old_backend = log.backend
  old_level = log.level
  log.backend = mem_backend = Log::MemoryBackend.new
  log.level = level
  begin
    yield
    mem_backend.entries
  ensure
    log.backend = old_backend
    log.level = old_level
  end
end
