require "crystal/unordered_hash"
require "./mu"

module Sync
  # Safe and fast `Hash`-like data-structure.
  #
  # `Map` stores the key-value pairs in multiple buckets, each bucket being a
  # smaller open hash table protected by its own rwlock, so only one bucket is
  # locked at a time, allowing other threads to keep interacting with the other
  # buckets. With enough buckets per available parallelism of the CPU, thread
  # contention over a shared map is significantly reduced when compared to a
  # single `Hash` protected with a single `RWLock`, leading to huge performance
  # improvements.
  #
  # `Map` is optimized for safe concurrent and parallel accesses of individual
  # entries. Methods that require to iterate, such as `#each`, `#keys`, or
  # `#values` must lock each bucket one after the other and may fare poorly.
  #
  # Follows the `Hash` interface, but isn't a drop-in replacement: the main
  # difference is that `Map` is unordered by design, while `Hash` is ordered
  # (key insertion order is retained). Enumeration thus follows no specific
  # order. Multiple runs can enumerate the map entries in the same or a
  # different order. A map can't be sorted, too.
  #
  # Each bucket will grow automatically when it reaches 75% occupancy, it may
  # also shrink when deleted entries reach 25% of its total capacity.
  #
  # NOTE: If `K` overrides either `Object#==` or `Object#hash(hasher)` then both
  # methods must be overridedn so that if two `K` are equal, then their hash
  # must also be equal (the opposite isn't true).
  #
  # NOTE: If `K` is a mutable type, changing the value of a key after it was
  # inserted into the `Map` may lead to undefined behaviour. You may re-index
  # the map by calling `#rehash` but the result may still be undefined.
  class Map(K, V)
    private struct Bucket(K, V)
      @mu = MU.new
      @h : Crystal::UnorderedHash(K, V)
      {% begin %}
        # avoid false sharing by padding the struct to CPU cache line (roughly)
        @pad = uninitialized UInt8[{{flag?(:bits64) ? 64 - 40 : 32 - 24}}]
      {% end %}

      forward_missing_to @h

      def initialize(initial_capacity : Int32)
        @h = Crystal::UnorderedHash(K, V).new(initial_capacity)
      end

      def initialize(@h : Crystal::UnorderedHash(K, V))
      end

      def read(&)
        @mu.rlock
        begin
          yield
        ensure
          @mu.runlock
        end
      end

      def write(&)
        @mu.lock
        begin
          yield
        ensure
          @mu.unlock
        end
      end

      def dup
        Bucket(K, V).new(@h.dup)
      end
    end

    def self.default_buckets_count : Int32
      count = System.effective_cpu_count
      count = System.cpu_count if count < 1
      Math.pw2ceil(count.to_i32.clamp(1..) * 4)
    end

    @buckets : Slice(Bucket(K, V))
    @bitshift : Int32

    # Creates a new map.
    #
    # The *initial_capacity* is the number of entries the map should hold across
    # all buckets. It will be clamped to at least as many buckets the map will
    # hold, then elevated to the next power of two in each bucket.
    #
    # The *buckets_count* is the number of buckets in the map. What matters is the
    # actual parallelism (number of hardware threads) of the CPU rather than the
    # total number of threads, but if your application only has 5 threads,
    # running on a CPU with 32 cores, you might want to limit the buckets' count
    # to the next power of two of 5 × 4 (32), instead of the default (128).
    def initialize(initial_capacity : Int32 = 8, buckets_count : Int32 = self.class.default_buckets_count)
      buckets_count = Math.pw2ceil(buckets_count.clamp(1..))
      capacity = (initial_capacity + (buckets_count - 1)) & ~(buckets_count - 1)

      @bitshift = (64 - buckets_count.trailing_zeros_count).to_i32

      @buckets = Slice(Bucket(K, V)).new(buckets_count) do
        Bucket(K, V).new(capacity // buckets_count)
      end
    end

    protected def initialize(@buckets, @bitshift)
    end

    def size : Int32
      size = 0
      each_bucket { |bucket| size += bucket.value.size }
      size
    end

    def empty? : Bool
      each_bucket { |bucket| return false unless bucket.value.empty? }
      true
    end

    def each(& : (K, V) ->) : Nil
      each_bucket do |bucket|
        next if bucket.value.empty?

        bucket.value.read do
          bucket.value.each { |key, value| yield key, value }
        end
      end
    end

    def each_key(& : K ->) : Nil
      each { |k, _| yield k }
    end

    def each_value(& : V ->) : Nil
      each { |_, v| yield v }
    end

    def keys : Array(K)
      keys = Array(K).new(size)
      each { |k, _| keys << k }
      keys
    end

    def values : Array(V)
      values = Array(V).new(size)
      each { |_, v| values << v }
      values
    end

    def has_key?(key : K) : Bool
      hash, bucket = determine_bucket(key)
      return false if bucket.value.empty?

      bucket.value.read do
        return bucket.value.has_key?(key, hash)
      end
    end

    def [](key : K) : V
      fetch(key) { raise KeyError.new "Missing key: #{key.inspect}" }
    end

    def []?(key : K) : V?
      fetch(key) { nil }
    end

    def fetch(key : K, default : U) : V | U forall U
      fetch(key) { default }
    end

    def fetch(key : K, & : -> U) : V | U forall U
      return yield if empty?

      hash, bucket = determine_bucket(key)
      return yield if bucket.value.empty?

      bucket.value.read do
        bucket.value.fetch(key, hash) { yield }
      end
    end

    def []=(key : K, value : V) : V
      put(key, value)
    end

    def put(key : K, value : V) : V
      hash, bucket = determine_bucket(key)

      bucket.value.write do
        bucket.value.put(key, hash, value)
      end

      value
    end

    def put_if_absent(key : K, value : V) : V
      put_if_absent(key) { value }
    end

    def put_if_absent(key : K, & : K -> V) : V
      hash, bucket = determine_bucket(key)

      bucket.value.write do
        bucket.value.fetch(key, hash) do
          value = yield key
          bucket.value.put(key, hash, value)
          value
        end
      end
    end

    def update(key : K, & : V -> V) : V
      hash, bucket = determine_bucket(key)
      bucket.value.write do
        bucket.value.update(key, hash) do |old_value|
          yield old_value
        end
      end
    end

    def delete(key : K) : V?
      delete(key) { nil }
    end

    def delete(key : K, & : -> U) : V | U forall U
      unless empty?
        hash, bucket = determine_bucket(key)

        unless bucket.value.empty?
          bucket.value.write do
            return bucket.value.delete(key, hash) { yield }
          end
        end
      end

      yield
    end

    def dup : Map(K, V)
      buckets = Slice(Bucket(K, V)).new(@buckets.size) do |i|
        bucket = @buckets.to_unsafe + i
        bucket.value.read { bucket.value.dup }
      end
      Map(K, V).new(buckets, @bitshift)
    end

    def to_h : Hash(K, V)
      hash = Hash(K, V).new(size)
      each_bucket do |bucket|
        next if bucket.value.empty?

        bucket.value.read do
          bucket.value.each do |k, v|
            hash[k] = v
          end
        end
      end
      hash
    end

    def to_a : Array({K, V})
      array = Array({K, V}).new(size)
      each_bucket do |bucket|
        next if bucket.value.empty?

        bucket.value.read do
          bucket.value.each do |k, v|
            array << {k, v}
          end
        end
      end
      array
    end

    # :nodoc:
    def hash(hasher)
      raise NotImplementedError.new("Sync::Map#hash(hasher)")
    end

    def rehash : Nil
      each_bucket do |bucket|
        bucket.value.write { bucket.value.rehash }
      end
    end

    private def each_bucket(&)
      @buckets.size.times do |i|
        yield @buckets.to_unsafe + i
      end
    end

    private def determine_bucket(key)
      hash = key.hash
      i = hash >> @bitshift
      raise "BUG: Sync::Map bucket index is out of bounds" unless 0 <= i < @buckets.size
      {hash, @buckets.to_unsafe + i}
    end
  end
end
