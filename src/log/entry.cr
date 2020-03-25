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

  def label
    case self
    when Debug   then "DEBUG"
    when Verbose then "VERBOSE"
    when Info    then "INFO"
    when Warning then "WARNING"
    when Error   then "ERROR"
    when Fatal   then "FATAL"
    when None    then "NONE"
    else
      raise "unreachable"
    end
  end
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
