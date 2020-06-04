require "crystal/datum"

# Base class for all backends.
abstract class Log::Backend
  def initialize(@dispatcher : Dispatcher)
  end

  # Writes the *entry* to this backend.
  abstract def write(entry : Entry)

  # Closes underlying resources used by this backend.
  def close
    @dispatcher.close
  end

  # :nodoc:
  def dispatch(entry : Entry)
    @dispatcher.dispatch entry, self
  end
end
