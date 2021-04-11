# A `Log::Backend` suitable for testing.
#
class Log::MemoryBackend < Log::Backend
  getter entries = Array(Log::Entry).new

  def initialize
    super(:direct)
  end

  def write(entry : Log::Entry) : Nil
    @entries << entry
  end
end
