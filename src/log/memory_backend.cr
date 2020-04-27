# A `Log::Backend` suitable for testing.
#
class Log::MemoryBackend < Log::Backend
  getter entries = Array(Log::Entry).new

  def write(entry : Log::Entry)
    @entries << entry
  end
end
