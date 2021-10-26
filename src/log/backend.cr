require "crystal/datum"

# Base class for all backends.
abstract class Log::Backend
  property dispatcher : Dispatcher

  def initialize(dispatch_mode : DispatchMode = :async)
    @dispatcher = Dispatcher.for(dispatch_mode)
  end

  def initialize(@dispatcher : Dispatcher)
  end

  # Writes the *entry* to this backend.
  abstract def write(entry : Entry)

  # Closes underlying resources used by this backend.
  def close : Nil
    @dispatcher.close
  end

  # :nodoc:
  def dispatch(entry : Entry)
    @dispatcher.dispatch entry, self
  end
end
