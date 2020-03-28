# A backend that broadcast to others backends.
# Each of the referenced backends may have a different severity level filter.
#
# When this backend level is set that level setting takes precedence
# over the severity filter of each referenced backend.
#
# This backend is not to be used explicitly. It is used by `Log::Builder` configuration
# to allow a given source to emit to multiple backends.
class Log::BroadcastBackend < Log::Backend
  property level : Severity? = nil

  @backends = Hash(Log::Backend, Severity).new

  def append(backend : Log::Backend, level : Severity)
    @backends[backend] = level
  end

  def write(entry : Entry)
    @backends.each do |backend, level|
      backend.write(entry) if (@level || level) <= entry.severity
    end
  end

  def close
  end

  # :nodoc:
  def min_level : Severity
    @backends.each_value.min? || Severity::None
  end
end
