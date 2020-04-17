# Immutable structured context information for logging.
#
# See `Log.context`, `Log.context=`, `Log::Context#clear`, `Log::Context#set`, `Log.with_context`.
class Log::Context
  Crystal.datum types: {bool: Bool, i: Int32, i64: Int64, f: Float32, f64: Float64, s: String, time: Time}, hash_key_type: String, immutable: true

  # Creates an empty `Log::Context`.
  def initialize : Nil
    @raw = Hash(String, Context).new
  end

  # Creates a `Log::Context` from the given *named_args*.
  def self.new(**named_args : Type) : self
    new named_args
  end

  # Creates `Log::Context` from the given *collection*.
  def initialize(collection : Hash | NamedTuple) : Nil
    @raw = raw = Hash(String, Context).new
    collection.each do |key, value|
      raw[key.to_s] = to_context(value)
    end
  end

  # :nodoc:
  def initialize(ary : Array) : Nil
    @raw = ary.map { |e| to_context(e) }
  end

  # Returns a new `Log::Context` with the keys and values of this context and *other* combined.
  # A value in *other* takes precedence over the one in this context.
  def merge(other : self) : self
    Context.new(self.as_h.merge(other.as_h).clone)
  end

  private def to_context(value)
    value.is_a?(Context) ? value : Context.new(value)
  end
end

class Fiber
  # :nodoc:
  property logging_context : Log::Context = Log::Context.new
end
