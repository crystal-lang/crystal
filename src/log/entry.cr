# A logging severity level.
enum Log::Severity
  # Used for tracing the code and trying to find one part of a function specifically.
  Trace
  # Used for information that is diagnostically helpful to people more than just developers (IT, sysadmins, etc.).
  Debug
  # Used for generally useful information to log.
  Info
  # Used for normal but significant conditions.
  Notice
  # Used for conditions that can potentially cause application oddities, but that can be automatically recovered.
  Warn
  # Used for any error that is fatal to the operation, but not to the service or application.
  Error
  # Used for any error that is forcing a shutdown of the service or application
  Fatal
  # Used only for severity level filter.
  None

  def label : String
    case self
    in Trace  then "TRACE"
    in Debug  then "DEBUG"
    in Info   then "INFO"
    in Notice then "NOTICE"
    in Warn   then "WARN"
    in Error  then "ERROR"
    in Fatal  then "FATAL"
    in None   then "NONE"
    end
  end
end

struct Log::Entry
  getter source : String
  getter severity : Severity
  getter message : String
  getter timestamp : Time
  getter context : Metadata = Log.context.metadata
  getter data : Metadata
  getter exception : Exception?

  def initialize(@source : String, @severity : Severity, @message : String, @data : Log::Metadata, @exception : Exception?, *, @timestamp = Time.local)
  end
end
