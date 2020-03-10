# A logging severity level.
enum Log::Severity
  Debug
  Verbose
  Info
  Warning
  Error
  Fatal
  # Used only for severity level filter.
  None
end

struct Log::Entry
  getter source : String
  getter severity : Severity
  getter message : String
  getter timestamp = Time.local
  getter context = Log.context
  getter exception : Exception?

  def initialize(@source : String, @severity : Severity, @message : String, @exception : Exception?)
  end
end
