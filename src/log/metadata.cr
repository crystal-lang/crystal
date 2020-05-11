# Immutable structured metadata information for logging.
#
# See `Log.context`, `Log.context=`, `Log::Context#clear`, `Log::Context#set`, `Log.with_context`, and `Log::Emitter`.
#
# NOTE: If you'd like to format the context as JSON, remember to `require "log/json"`.
class Log::Metadata
  Crystal.datum types: {nil: Nil, bool: Bool, i: Int32, i64: Int64, f: Float32, f64: Float64, s: String, time: Time}, hash_key_type: String, immutable: true, target_type: Log::Metadata

  # Returns an empty `Log::Metadata`.
  #
  # NOTE: Since `Log::Metadata` is immutable, it's safe to share this instance.
  class_getter empty : Log::Metadata = Log::Metadata.new

  # Creates an empty `Log::Metadata`.
  def initialize
    @raw = Hash(String, Metadata).new
  end

  # Creates `Log::Metadata` from the given *values*.
  # All keys are converted to `String`
  def initialize(hash : NamedTuple | Hash)
    @raw = raw = Hash(String, Metadata).new
    hash.each do |key, value|
      raw[key.to_s] = to_metadata(value)
    end
  end

  # :nodoc:
  def initialize(ary : Array)
    @raw = ary.map { |e| to_metadata(e) }
  end

  private def to_metadata(value)
    value.is_a?(Metadata) ? value : Metadata.new(value)
  end

  # Returns a `Metadata` with the information of the argument.
  # Used to handle `Log::Context#set` and `Log#Emitter.emit` overloads.
  def self.build(value : NamedTuple | Hash)
    return @@empty if value.empty?
    Metadata.new(value)
  end

  def self.build(value : Metadata)
    value
  end

  # Returns a `Log::Metadata` with all the entries of *self*
  # and *other*. If a key is defined in both, the values in *other* are used.
  def extend(other : NamedTuple | Hash) : Metadata
    return Metadata.build(other) if self.object_id == @@empty.object_id
    return self if other.empty?

    Metadata.build(self.raw.as(Hash).merge(other.to_h))
  end
end

class Fiber
  # :nodoc:
  getter logging_context : Log::Metadata { Log::Metadata.empty }

  # :nodoc:
  def logging_context=(value : Log::Metadata)
    raise ArgumentError.new "Expected hash context, not #{value.raw.class}" unless value.as_h?
    @logging_context = value
  end
end
