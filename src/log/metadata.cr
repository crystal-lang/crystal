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
  # The maximum size this metadata would need.
  # Initially is the parent.max_total_size + entries.size .
  # When the metadata is defragmented max_total_size will be updated with size
  protected getter max_total_size : Int32
  @max_total_size = uninitialized Int32
  # How many entries are potentially overridden from parent (ie: initial entries.size)
  @overridden_size = uninitialized Int32
  # How many entries are stored from @first.
  # Initially are @overridden_size, the one explicitly overridden in entries argument.
  # When the metadata is defragmented @size will be increased up to
  # the actual number of entries resulting from merging the parent
  @size = uninitialized Int32
  # @first needs to be the last ivar of Metadata. The entries are allocated together with self
  @first = uninitialized Entry

  def self.new(parent : Metadata? = nil, entries : NamedTuple | Hash = NamedTuple.new) : self
    data_size = instance_sizeof(self) + sizeof(Entry) * {entries.size + (parent.try(&.max_total_size) || 0) - 1, 0}.max
    data = GC.malloc(data_size).as(self)
    data.setup(parent, entries)
    data
  end

  def dup : self
    self
  end

  protected def setup(@parent : Metadata?, entries : NamedTuple | Hash)
    @size = @overridden_size = entries.size
    parent_size = (@parent.try(&.max_total_size) || 0)
    @max_total_size = @size + parent_size
    ptr_entries = pointerof(@first)

    # Use parent_size as offset to make room for parent entries when defragging
    if entries.is_a?(NamedTuple)
      entries.each_with_index(parent_size) do |key, value, i|
        ptr_entries[i] = {key: key, value: Value.to_metadata_value(value)}
      end
    else
      entries.each_with_index(parent_size) do |(key, value), i|
        ptr_entries[i] = {key: key, value: Value.to_metadata_value(value)}
      end
    end
  end

  # Returns a `Metadata` with the information of the argument.
  # Used to handle `Log::Context#set` and `Log#Emitter.emit` overloads.
  def self.build(value : NamedTuple | Hash) : self
    return @@empty if value.empty?
    Metadata.new(nil, value)
  end

  # :ditto:
  def self.build(value : Metadata) : Metadata
    value
  end

  # Returns a `Log::Metadata` with all the entries of `self`
  # and *other*. If a key is defined in both, the values in *other* are used.
  def extend(other : NamedTuple | Hash) : Metadata
    return Metadata.build(other) if self.empty?
    return self if other.empty?

    Metadata.new(self, other)
  end

  def empty? : Bool
    parent = @parent

    @size == 0 && (parent.nil? || parent.empty?)
  end

  # Removes the reference to *parent*. Flattening the entries from it into `self`.
  # `self` was originally allocated with enough entries to perform this action.
  #
  # If multiple threads execute defrag concurrently, the entries
  # will be recomputed, but the result should be the same.
  #
  # * @parent.nil? signals if the defrag is needed/done
  # * The values of @overridden_size, pointerof(@first) are never changed
  # * @parent is set at the very end of the method
  protected def defrag
    parent = @parent
    return if parent.nil?

    ptr_entries = pointerof(@first)
    next_free_entry = ptr_entries
    # Math to get @size from end
    my_entries = ptr_entries + (@max_total_size - @size)

    # Copy all parent entries to the beginning of "our" entries
    parent_size = 0
    parent.each_with_index do |(key, value), i|
      next_free_entry.value = {key: key, value: value}
      next_free_entry += 1
      parent_size += 1
    end

    total_size = parent_size

    # Move all of "our" entries, but overwrite parent if exists
    @size.times do |i|
      entry = my_entries[i]

      overwritten = false
      parent_size.times do |j|
        if ptr_entries[j][:key] == entry[:key]
          # Overwrite parent entry with our entry
          ptr_entries[j] = {key: entry[:key], value: entry[:value]}
          overwritten = true
          break
        end
      end
      next if overwritten

      next_free_entry.value = {key: entry[:key], value: entry[:value]}
      next_free_entry += 1
      total_size += 1
    end

    @size = total_size
    @max_total_size = total_size
    @parent = nil
  end

  def each(& : {Symbol, Value} ->)
    defrag
    ptr_entries = pointerof(@first)

    @size.times do |i|
      entry = ptr_entries[i]
      yield({entry[:key], entry[:value]})
    end
  end

  def [](key : Symbol) : Value
    fetch(key) { raise KeyError.new "Missing metadata key: #{key.inspect}" }
  end

  def []?(key : Symbol) : Value?
    fetch(key) { nil }
  end

  def fetch(key, &)
    entry = find_entry(key)
    entry ? entry[:value] : yield key
  end

  protected def find_entry(key) : Entry?
    # checking the @parent before @size ensures that if other
    # thread is doing defrag, the results will be consistent
    # without locking.

    parent = @parent

    ptr_entries = pointerof(@first)
    # Math to get @size from end
    my_entries = ptr_entries + (@max_total_size - @size)
    @size.times do |i|
      return my_entries[i] if my_entries[i][:key] == key
    end

    return parent.find_entry(key) if parent

    nil
  end

  def ==(other : Metadata) : Bool
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

  def ==(other)
    false
  end

  def hash(hasher)
    to_a.sort_by!(&.[0]).hash(hasher)
  end

  def to_s(io : IO) : Nil
    found_one = false
    each do |(key, value)|
      io << ", " if found_one
      io << key
      io << ": "
      value.inspect(io)
      found_one = true
    end
  end

  struct Value
    Crystal.datum types: {nil: Nil, bool: Bool, i: Int32, i64: Int64, u: UInt32, u64: UInt64, f: Float32, f64: Float64, s: String, time: Time}, hash_key_type: String, immutable: false, target_type: Log::Metadata::Value

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
    def self.to_metadata_value(value : _) : Metadata::Value
      value.is_a?(Value) ? value : Value.new(value)
    end
  end
end

class Fiber
  # :nodoc:
  getter logging_context : Log::Metadata { Log::Metadata.empty }

  # :nodoc:
  def logging_context=(value : Log::Metadata) : Log::Metadata
    @logging_context = value
  end
end

class String
  def ==(other : Log::Metadata::Value)
    other == self
  end
end

struct Value
  def ==(other : Log::Metadata::Value)
    other == self
  end
end
