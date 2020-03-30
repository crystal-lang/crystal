# The `Log` class provides a logging utility that you can use to output messages.
#
# The messages, or `Log::Entry` have associated levels, such as `Info` or `Error`
# that indicate their importance. See `Log::Severity`.
#
# To log a message `debug`, `verbose`, `info`, `warn`, `error`, and `fatal` methods
# can be used. They expect a block that will evaluate to the message of the entry.
#
# ```
# require "log"
#
# Log.info { "Program started" }
# ```
#
# If you want to log an exception, you can indicate it in the `exception:` named argument.
#
# ```
# Log.warn(exception: e) { "Oh no!" }
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
#   Log = ::Log.for("db") # => Log for db source
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
#   Log = DB::Log.for("pool") # => Log for db.pool source
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
#   Log = ::Log.for(self) # => Log for db source
# end
# ```
#
# ### Configure logging explicitly in the code
#
# Use `Log.builder` to indicate which sources should go to which backends.
#
# You can indicate actual sources or patterns.
#
# * the empty string matches only the top-level source
# * `*` matches all the sources
# * `foo.bar.*` matches `foo.bar` and every nested source
# * `foo.bar` matches `foo.bar`, but not its nested sources
#
#
# The following configuration will setup for all sources to emit
# warnings (or higher) to `STDOUT`, allow any of the `db.*` and
# nested source to emit debug (or higher), and to also emit for all
# sources errors (or higher) to an elasticsearch backend.
#
# ```
# backend = Log::IOBackend.new
# Log.builder.bind "*", :warning, backend
# Log.builder.bind "db.*", :debug, backend
# Log.builder.bind "*", :error, ElasticSearchBackend.new("http://localhost:9200")
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
# The environment variables `CRYSTAL_LOG_LEVEL` and `CRYSTAL_LOG_SOURCES` are used to indicate
# which severity level to emit (defaults to `INFO`; use `NONE` to skip all messages) and to restrict
# which sources you are interested in.
#
# The valid values for `CRYSTAL_LOG_SOURCES` are:
#
# * the empty string matches only the top-level source (default)
# * `*` matches all the sources
# * `foo.bar.*` matches `foo.bar` and every nested source
# * `foo.bar` matches `foo.bar`, but not its nested sources
# * Any comma separated combination of the above
#
# The logs are emitted to `STDOUT` using a `Log::IOBackend`.
#
# If `Log.setup_from_env` is called on startup you can tweak the logging as:
#
# ```
# $ CRYSTAL_LOG_LEVEL=DEBUG CRYSTAL_LOG_SOURCES=* ./bin/app
# ```
class Log
end

# list all files but log/config which requires yaml
require "./log/backend"
require "./log/broadcast_backend"
require "./log/builder"
require "./log/context"
require "./log/entry"
require "./log/main"
require "./log/env_config"
require "./log/log"
require "./log/memory_backend"
require "./log/io_backend"
