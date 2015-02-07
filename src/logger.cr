class Logger
  property :level, :progname, :formatter

  UNKNOWN = 5
  FATAL = 4
  ERROR = 3
  WARN = 2
  INFO = 1
  DEBUG = 0

  SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

  DEFAULT_FORMATTER = ->(severity : String, datetime : Time, progname : String, message : String) {
    "#{severity[0]}, [#{datetime} ##{Process.pid}] #{severity.rjust(5)} -- #{progname}: #{message}"
  }

  def initialize(@io : IO)
    @level = INFO
    @formatter = DEFAULT_FORMATTER
    @progname = ""
  end

  def <<(message)
    @io << message
  end

  def close
    @io.close
  end

  macro log_level(name)
    def {{name.id.downcase}}?
      level <= {{name.id}}
    end

    def {{name.id.downcase}}(message, progname = nil)
      log({{name.id}}, message, progname)
    end
  end

  def unknown(message, progname = nil)
    log(UNKNOWN, message, progname)
  end

  log_level FATAL
  log_level ERROR
  log_level WARN
  log_level INFO
  log_level DEBUG

  def log(severity, message, progname = nil)
    return if severity < level
    @io << formatter.call(SEV_LABEL[severity], Time.now, progname || @progname || "", message) + "\n"
  end
end
