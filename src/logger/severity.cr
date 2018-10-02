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

    # Mutes all output when used as a threshold. Attempting to logging at this
    # level will produce UNKNOWN instead.
    SILENT
  end

  DEFAULT_SEVERITY = Severity::INFO
  {% for name in Severity.constants %}
    {{name.id}} = Severity::{{name.id}}
  {% end %}
end
