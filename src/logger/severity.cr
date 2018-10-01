class Logger
  # A logger severity level.
  enum Severity
    # Low-level information for developers
    DEBUG
    # Generic (useful) information about system operation
    INFO
    # A warning
    WARN
    # A handleable error condition
    ERROR
    # An unhandleable error that results in a program crash
    FATAL
    UNKNOWN
  end
end
