require "./logger/*"

# The `Logger` class provides a logging utility that you can (and should) use
# to output messages.
#
# The logging system consists of three parts: a `Logger`, which is associated
# with a single component of your program (usually a class or module), a
# `Handler`, which receives messages from `Logger` and filters them based on
# severity level, and one or more `Adapter` objects, which output log messages
# in some way, such as by writing them to an `IO` or sending them to a
# database.
#
# Each message has an associated level, such as `INFO` or `ERROR`, that
# indicates its importance. You can assign different severity thresholds to
# different components of your program, and the `Handler` will ignore messages
# that do not meet the respective threshold.
#
# The bulk of the logging functionality is contained in the `Handler` class.
# `Logger` itself mostly delegates methods to a handler, supplying its
# component name.
#
# Crystal provides a default `Handler` whose adapter writes to `STDERR`, so if
# all you want is some console output getting started is easy:
# ```
# require "logger"
#
# module MyProgram
#   @@logger = Logger.new(name)
#
#   class Config
#     @@logger = Logger.new(name)
#
#     def initialize
#       @@logger.debug "Finding config..." # Not printed; default level is INFO
#       @@logger.error "No config found!"
#     end
#   end
#
#   def self.main
#     @@logger.info "Initializing..."
#     Config.new
#   end
# end
#
# MyProgram.main
#
# # Produces:
# # I, [2018-04-04 13:14:58 -07:00 #14093]  INFO -- program / MyProgram: Initializing...
# # E, [2018-04-04 13:14:58 -07:00 #14093] ERROR -- program / MyProgram::Config: No config found!
# ```
class Logger
  # The `Handler` instance that will filter messages by level and pass them to
  # its adapters.
  getter handler
  # The component string that will be passed to `handler`.
  getter component

  # Creates a new logger for the given component and log handler.
  def initialize(@component : String, @handler = Logger.default_handler)
  end

  # Creates a new logger for the root component.
  def self.new(handler = Logger.default_handler)
    new("", handler)
  end

  {% for name in Severity.constants %}
    # Returns `true` if a message with severity `{{name.id}}` will be logged
    # at the current level.
    def {{ name.id.downcase }}?
      level! <= {{ name.id }}
    end

    {% unless name.stringify == "SILENT" %}
      # Sends *message* with severity `{{name.id}}` to the handler.
      def {{ name.id.downcase }}(message)
        @handler.log({{ name.id }}, message, @component)
      end

      # Forwards the block to the handler with severity `{{name.id}}`. If this
      # meets or exceeds this logger's level, the handler will evaluate the
      # block and log the result. This is preferable to passing the message
      # directly when building the message adds significant overhead.
      def {{ name.id.downcase }}
        @handler.log({{ name.id }}, @component) { yield }
      end
    {% end %}
  {% end %}

  # Delegates to `Handler#level?`, passing `component`.
  def level?
    @handler.level?(@component)
  end

  # Delegates to `Handler#level!`, passing `component`.
  def level!
    @handler.level!(@component)
  end

  # Delegates to `Handler#set_level`, passing `component`.
  def level=(severity : Severity)
    @handler.set_level(@component, severity)
  end

  # Delegates to `Handler#unset_level`, passing `component`.
  def level=(severity : Nil)
    @handler.unset_level(@component)
  end
end
