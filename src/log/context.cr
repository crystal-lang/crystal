# Immutable structured context information for logging.
#
# See `Log.context`, `Log.context=`, `Log::Context#clear`, `Log::Context#set`, `Log.with_context`.
#
# NOTE: If you'd like to format the context as JSON, remember to `require "log/json"`.
class Log::Context
  Crystal.datum types: {nil: Nil, bool: Bool, i: Int32, i64: Int64, f: Float32, f64: Float64, s: String, time: Time}, hash_key_type: String, immutable: true, target_type: Log::Context

  # Returns an empty `Log::Context`.
  #
  # NOTE: Since `Log::Context` is immutable, it's safe to share this instance.
  class_getter empty : Log::Context = Log::Context.new

  # Creates an empty `Log::Context`.
  def initialize
    @raw = Hash(String, Context).new
  end

  # Creates `Log::Context` from the given *tuple*.
  def initialize(tuple : NamedTuple)
    @raw = raw = Hash(String, Context).new
    tuple.each do |key, value|
      raw[key.to_s] = to_context(value)
    end
  end

  # Creates `Log::Context` from the given *hash*.
  def initialize(hash : Hash(String, V)) forall V
    @raw = raw = Hash(String, Context).new
    hash.each do |key, value|
      raw[key] = to_context(value)
    end
  end

  # Creates `Log::Context` from the given *hash*.
  def initialize(hash : Hash(Symbol, V)) forall V
    @raw = raw = Hash(String, Context).new
    hash.each do |key, value|
      raw[key.to_s] = to_context(value)
    end
  end

  # :nodoc:
  def initialize(ary : Array)
    @raw = ary.map { |e| to_context(e) }
  end

  # Returns a new `Log::Context` with the keys and values of this context and *other* combined.
  # A value in *other* takes precedence over the one in this context.
  def merge(other : Context)
    return other if self.object_id == @@empty.object_id
    return self if other.object_id == @@empty.object_id
    Context.new(self.as_h.merge(other.as_h).clone)
  end

  private def to_context(value)
    value.is_a?(Context) ? value : Context.new(value)
  end
end

class Fiber
  # :nodoc:
  getter logging_context : Log::Context { Log::Context.empty }

  # :nodoc:
  def logging_context=(value : Log::Context)
    raise ArgumentError.new "Expected hash context, not #{value.raw.class}" unless value.as_h?
    @logging_context = value
  end
end
