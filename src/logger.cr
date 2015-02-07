class Logger(T)
  property :level, :progname, :formatter

  enum Severity : Int32
    UNKNOWN = 5
    FATAL = 4
    ERROR = 3
    WARN = 2
    INFO = 1
    DEBUG = 0
  end

  alias Formatter = String, Time, String, String ->

  DEFAULT_FORMATTER = Formatter.new do |severity, datetime, progname, message|
    "#{severity[0]}, [#{datetime} ##{Process.pid}] #{severity.rjust(5)} -- #{progname}: #{message}"
  end

  def initialize(@io : T)
    @level = Severity::INFO
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
    {{name.id}} = Severity::{{name.id}}

    def {{name.id.downcase}}?
      level <= Severity::{{name.id}}
    end

    def {{name.id.downcase}}(message, progname = nil)
      log(Severity::{{name.id}}, message, progname)
    end

    def {{name.id.downcase}}(progname = nil)
      log(Severity::{{name.id}}, progname) { yield }
    end
  end

  log_level UNKNOWN
  log_level FATAL
  log_level ERROR
  log_level WARN
  log_level INFO
  log_level DEBUG

  def log(severity, message, progname = nil)
    return if severity < level
    @io.puts format(severity, Time.now, progname || @progname, message)
  end

  def log(severity, progname = nil)
    return if severity < level
    @io.puts format(severity, Time.now, progname || @progname, yield)
  end

  def format(severity, datetime, progname, message)
    label = severity == Severity::UNKNOWN ? "ANY" : severity.to_s
    formatter.call(label, Time.now, progname.to_s, message)
  end
end
