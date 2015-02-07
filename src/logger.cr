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

    def {{name.id.downcase}}(progname = nil)
      log({{name.id}}, nil, progname) { yield }
    end
  end

  def unknown(message, progname = nil)
    log(UNKNOWN, message, progname)
  end

  def unknown(progname = nil)
    log(UNKNOWN, nil, progname) { yield }
  end

  log_level FATAL
  log_level ERROR
  log_level WARN
  log_level INFO
  log_level DEBUG

  def log(severity, message, progname = nil)
    return if severity < level
    @io << format(severity, Time.now, progname || @progname, message)
  end

  def log(severity, message = nil, progname = nil)
    return if severity < level
    @io << format(severity, Time.now, progname || @progname, yield)
  end

  def format(severity, datetime, progname, message)
    formatter.call(SEV_LABEL[severity], Time.now, progname.to_s, message) + "\n"
  end
end
