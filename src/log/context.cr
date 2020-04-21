# Immutable structured context information for logging.
#
# See `Log.context`, `Log.context=`, `Log::Context#clear`, `Log::Context#set`, `Log.with_context`.
#
# NOTE: If you'd like to format the context as JSON, remember to `require "log/json"`.
class Log::Context
  Crystal.datum types: {nil: Nil, bool: Bool, i: Int32, i64: Int64, f: Float32, f64: Float64, s: String, time: Time}, hash_key_type: String, immutable: true, target_type: Log::Context

  # Creates an empty `Log::Context`.
  def initialize
    @raw = Hash(String, Context).new
  end

  # Creates a `Log::Context` from the given *named_args*.
  def self.new(**named_args : Type)
    new named_args
  end

  # Creates `Log::Context` from the given *collection*.
  def initialize(collection : Hash(String | Symbol, _) | NamedTuple)
    @raw = raw = Hash(String, Context).new
    collection.each do |key, value|
      raw[key.to_s] = to_context(value)
    end
  end

  # :nodoc:
  def initialize(ary : Array)
    @raw = ary.map { |e| to_context(e) }
  end

  # Returns a new `Log::Context` with the keys and values of this context and *other* combined.
  # A value in *other* takes precedence over the one in this context.
  def merge(other : self)
    Context.new(self.as_h.merge(other.as_h).clone)
  end

  private def to_context(value)
    value.is_a?(Context) ? value : Context.new(value)
  end
end

class Fiber
  # :nodoc:
  getter logging_context : Log::Context = Log::Context.new

  # :nodoc:
  def logging_context=(value : Log::Context)
    raise ArgumentError.new "Expected hash context, not #{value.raw.class}" unless value.as_h?
    @logging_context = value
  end
end
