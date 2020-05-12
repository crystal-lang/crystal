# Immutable structured metadata information for logging.
#
# See `Log.context`, `Log.context=`, `Log::Context#clear`, `Log::Context#set`, `Log.with_context`, and `Log::Emitter`.
#
# NOTE: If you'd like to format the context as JSON, remember to `require "log/json"`.
class Log::Metadata
  struct Value; end

  include Enumerable({Symbol, Log::Metadata::Value})
  alias Entry = {key: Symbol, value: Value}

  # Returns an empty `Log::Metadata`.
  #
  # NOTE: Since `Log::Metadata` is immutable, it's safe to share this instance.
  class_getter empty : Log::Metadata = Log::Metadata.new

  @parent : Metadata?
  @size = uninitialized Int32
  # @first needs to be the last ivar of Metadata. The entries are allocated together with self
  @first = uninitialized Entry

  def self.new(parent : Metadata? = nil, entries : NamedTuple | Hash = NamedTuple.new)
    data_size = instance_sizeof(self) + sizeof(Entry) * {entries.size - 1, 0}.max
    data = GC.malloc(data_size).as(self)
    data.setup(parent, entries)
    data
  end

  protected def setup(@parent : Metadata?, entries : NamedTuple | Hash)
    @size = entries.size
    ptr_entries = pointerof(@first)

    if entries.is_a?(NamedTuple)
      entries.each_with_index do |key, value, i|
        ptr_entries[i] = {key: key, value: Value.to_metadata_value(value)}
      end
    else
      entries.each_with_index do |(key, value), i|
        ptr_entries[i] = {key: key, value: Value.to_metadata_value(value)}
      end
    end
  end

  # Returns a `Metadata` with the information of the argument.
  # Used to handle `Log::Context#set` and `Log#Emitter.emit` overloads.
  def self.build(value : NamedTuple | Hash)
    return @@empty if value.empty?
    Metadata.new(nil, value)
  end

  # :ditto:
  def self.build(value : Metadata)
    value
  end

  # Returns a `Log::Metadata` with all the entries of *self*
  # and *other*. If a key is defined in both, the values in *other* are used.
  def extend(other : NamedTuple | Hash) : Metadata
    return Metadata.build(other) if self.empty?
    return self if other.empty?

    Metadata.new(self, other)
  end

  def empty?
    parent = @parent

    @size == 0 && (parent.nil? || parent.empty?)
  end

  def each(&block : {Symbol, Value} -> _)
    ptr_entries = pointerof(@first)

    @size.times do |i|
      entry = ptr_entries[i]
      block.call({entry[:key], entry[:value]})
    end

    if parent = @parent
      parent.each do |(key, value)|
        # return it if it's not already returned by the previous circle
        already_yielded = false
        @size.times do |i|
          if ptr_entries[i][:key] == key
            already_yielded = true
            break
          end
        end

        block.call({key, value}) unless already_yielded
      end
    end
  end

  def ==(other : Metadata)
    self_kv = self.to_a
    other_kv = other.to_a

    return false if self_kv.size != other_kv.size

    # sort kv tuples by key
    self_kv.sort_by!(&.[0])
    other_kv.sort_by!(&.[0])

    self_kv.each_with_index do |(key, value), i|
      return false unless key == other_kv[i][0] && value == other_kv[i][1]
    end

    true
  end

  # :nodoc:
  def ==(other)
    false
  end

  def to_s(io : IO) : Nil
    io << '{'
    found_one = false
    each do |(key, value)|
      io << ", " if found_one
      key.inspect(io)
      io << " => "
      value.inspect(io)
      found_one = true
    end
    io << '}'
  end

  struct Value
    Crystal.datum types: {nil: Nil, bool: Bool, i: Int32, i64: Int64, f: Float32, f64: Float64, s: String, time: Time}, hash_key_type: String, immutable: false, target_type: Log::Metadata::Value

    # Creates `Log::Metadata` from the given *values*.
    # All keys are converted to `String`
    def initialize(hash : NamedTuple | Hash)
      @raw = raw = Hash(String, Value).new
      hash.each do |key, value|
        raw[key.to_s] = Value.to_metadata_value(value)
      end
    end

    # :nodoc:
    def initialize(ary : Array)
      @raw = ary.map { |e| Value.to_metadata_value(e) }
    end

    # :nodoc:
    def self.to_metadata_value(value)
      value.is_a?(Value) ? value : Value.new(value)
    end
  end
end

class Fiber
  # :nodoc:
  getter logging_context : Log::Metadata { Log::Metadata.empty }

  # :nodoc:
  def logging_context=(value : Log::Metadata)
    @logging_context = value
  end
end
