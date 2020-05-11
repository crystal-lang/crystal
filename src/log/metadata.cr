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

  # Creates `Log::Metadata` from the given *tuple*.
  def initialize(tuple : NamedTuple)
    @raw = raw = Hash(String, Metadata).new
    tuple.each do |key, value|
      raw[key.to_s] = to_metadata(value)
    end
  end

  # Creates `Log::Metadata` from the given *hash*.
  def initialize(hash : Hash(String, V)) forall V
    @raw = raw = Hash(String, Metadata).new
    hash.each do |key, value|
      raw[key] = to_metadata(value)
    end
  end

  # Creates `Log::Metadata` from the given *hash*.
  def initialize(hash : Hash(Symbol, V)) forall V
    @raw = raw = Hash(String, Metadata).new
    hash.each do |key, value|
      raw[key.to_s] = to_metadata(value)
    end
  end

  # :nodoc:
  def initialize(ary : Array)
    @raw = ary.map { |e| to_metadata(e) }
  end

  # Returns a new `Log::Metadata` with the keys and values of this context and *other* combined.
  # A value in *other* takes precedence over the one in this context.
  def merge(other : Metadata)
    return other if self.object_id == @@empty.object_id
    return self if other.object_id == @@empty.object_id
    Metadata.new(self.as_h.merge(other.as_h).clone)
  end

  private def to_metadata(value)
    value.is_a?(Metadata) ? value : Metadata.new(value)
  end

  # Returns a `Metadata` with the information of the argument.
  # Used to handle `Log::Context#set` and `Log#Emitter.emit` overloads.
  def self.build(value : Nil)
    Metadata.empty
  end

  # :ditto:
  def self.build(value : NamedTuple)
    Metadata.new(value)
  end

  # :ditto:
  def self.build(value : Hash(String, V)) forall V
    Metadata.new(value)
  end

  # :ditto:
  def self.build(value : Hash(Symbol, V)) forall V
    Metadata.new(value)
  end

  # :ditto:
  def self.build(value : Metadata)
    value
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
