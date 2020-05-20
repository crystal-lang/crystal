require "crystal/datum"

# Base class for all backends.
abstract class Log::Backend
  # Writes the *entry* to this backend.
  abstract def write(entry : Entry)

  # Closes underlying resources used by this backend.
  def close
  end
end
