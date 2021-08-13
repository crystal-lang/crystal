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

  def initialize
    super(:direct)
  end

  def append(backend : Log::Backend, level : Severity)
    @backends[backend] = level
  end

  def write(entry : Entry) : Nil
    @backends.each do |backend, level|
      backend.dispatch(entry) if (@level || level) <= entry.severity
    end
  end

  def close : Nil
    @backends.each_key &.close
  end

  # :nodoc:
  def min_level : Severity
    @backends.each_value.min? || Severity::None
  end

  # :nodoc:
  def single_backend?
    first_backend = @backends.first_key?
    first_level = @backends[first_backend]

    if first_backend && @backends.size == 1
      {first_backend, first_level}
    else
      nil
    end
  end

  # :nodoc:
  def remove(backend : Log::Backend)
    @backends.delete(backend)
  end
end
