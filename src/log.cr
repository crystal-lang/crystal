# The `Log` class provides a logging utility that you can use to output messages.
#
# The messages, or `Log::Entry` have associated levels, such as `Info` or `Error`
# that indicate their importance. See `Log::Severity`.
#
# To log a message use the `#trace`, `#debug`, `#info`, `#notice`, `#warn`,
# `#error`, and `#fatal` methods. They expect a block that will evaluate to the
# message of the entry:
#
# NOTE: To use `Log`, you must explicitly import it with `require "log"`
#
# ```
# require "log"
#
# Log.info { "Program started" }
# ```
#
# Data can be associated with a log entry via the `Log::Emitter` yielded in the logging methods.
#
# ```
# Log.info &.emit("User logged in", user_id: 42)
# ```
#
# If you want to log an exception, you can indicate it in the `exception:` named argument.
#
# ```
# Log.warn(exception: e) { "Oh no!" }
# Log.warn exception: e, &.emit("Oh no!", user_id: 42)
# ```
#
# The block is only evaluated if the current message is to be emitted to some `Log::Backend`.
#
# To add structured information to the message you can use the `Log::Context`.
#
# When creating log messages they belong to a _source_. If the top-level `Log` is used
# as in the above examples its source is the empty string.
#
# The source can be used to identify the module or part of the application that is logging.
# You can configure for each source a different level to filter the messages.
#
# A recommended pattern is to declare a `Log` constant in the namespace of your shard or module as follows:
#
# ```
# module DB
#   Log = ::Log.for("db") # Log for db source
#
#   def do_something
#     Log.info { "this is logged in db source" }
#   end
# end
#
# DB::Log.info { "this is also logged in db source" }
# Log.for("db").info { "this is also logged in db source" }
# Log.info { "this is logged in top-level source" }
# ```
#
# That way, any `Log.info` call within the `DB` module will use the `db` source. And not the top-level `::Log.info`.
#
# Sources can be nested. Continuing the last example, to declare a `Log` constant `db.pool` source you can do as follows:
#
# ```
# class DB::Pool
#   Log = DB::Log.for("pool") # Log for db.pool source
# end
# ```
#
# A `Log` will emit the messages to the `Log::Backend`s attached to it as long as
# the configured severity filter `level` permits it.
#
# Logs can also be created from a type directly. For the type `DB::Pool` the source `db.pool` will be used.
# For generic types as `Foo::Bar(Baz)` the source `foo.bar` will be used (i.e. without generic arguments).
#
# ```
# module DB
#   Log = ::Log.for(self) # Log for db source
# end
# ```
#
# ### Default logging configuration
#
# By default entries from all sources with `Info` and above severity will
# be logged to `STDOUT` using the `Log::IOBackend`.
#
# If you need to change the default level, backend or sources call `Log.setup` upon startup.
#
# NOTE: Calling `setup` will override previous `setup` calls.
#
# ```
# Log.setup(:debug)                     # Log debug and above for all sources to STDOUT
# Log.setup("myapp.*, http.*", :notice) # Log notice and above for myapp.* and http.* sources only, and log nothing for any other source.
# backend_with_formatter = Log::IOBackend.new(formatter: custom_formatter)
# Log.setup(:debug, backend_with_formatter) # Log debug and above for all sources to using a custom backend
# ```
#
# ### Configure logging explicitly in the code
#
# Use `Log.setup` methods to indicate which sources should go to which backends.
#
# You can indicate actual sources or patterns.
#
# * the empty string matches only the top-level source
# * `*` matches all the sources
# * `foo.bar.*` matches `foo.bar` and every nested source
# * `foo.bar` matches `foo.bar`, but not its nested sources
# * Any comma separated combination of the above
#
# The following configuration will setup for all sources to emit
# warnings (or higher) to `STDOUT`, allow any of the `db.*` and
# nested source to emit debug (or higher), and to also emit for all
# sources errors (or higher) to an elasticsearch backend.
#
# ```
# Log.setup do |c|
#   backend = Log::IOBackend.new
#
#   c.bind "*", :warn, backend
#   c.bind "db.*", :debug, backend
#   c.bind "*", :error, ElasticSearchBackend.new("http://localhost:9200")
# end
# ```
#
# ### Configure logging from environment variables
#
# Include the following line to allow configuration from environment variables.
#
# ```
# Log.setup_from_env
# ```
#
# The environment variable `LOG_LEVEL` is used to indicate which severity level to emit.
# By default entries from all sources with `Info` and above severity will
# be logged to `STDOUT` using the `Log::IOBackend`.
#
# To change the level and sources change the environment variable value:
#
# ```console
# $ LOG_LEVEL=DEBUG ./bin/app
# ```
#
# You can tweak the default values (used when `LOG_LEVEL` variable is not defined):
#
# ```
# Log.setup_from_env(default_level: :error)
# ```
#
class Log
end

# list all files but log/config which requires yaml
require "./log/backend"
require "./log/broadcast_backend"
require "./log/builder"
require "./log/metadata"
require "./log/entry"
require "./log/format"
require "./log/main"
require "./log/setup"
require "./log/log"
require "./log/memory_backend"
require "./log/io_backend"
require "./log/dispatch"

Log.setup
