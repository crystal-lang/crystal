require "crystal/hasher"

# A `Hash` represents a collection of key-value mappings, similar to a dictionary.
#
# Main operations are storing a key-value mapping (`#[]=`) and
# querying the value associated to a key (`#[]`). Key-value mappings can also be
# deleted (`#delete`).
# Keys are unique within a hash. When adding a key-value mapping with a key that
# is already in use, the old value will be forgotten.
#
# ```
# # Create a new Hash for mapping String to Int32
# hash = Hash(String, Int32).new
# hash["one"] = 1
# hash["two"] = 2
# hash["one"] # => 1
# ```
#
# [Hash literals](https://crystal-lang.org/reference/syntax_and_semantics/literals/hash.html)
# can also be used to create a `Hash`:
#
# ```
# {"one" => 1, "two" => 2}
# ```
#
# Implementation is based on an open hash table.
# Two objects refer to the same hash key when their hash value (`Object#hash`)
# is identical and both objects are equal to each other (`Object#==`).
#
# Enumeration follows the order that the corresponding keys were inserted.
#
# NOTE: When using mutable data types as keys, changing the value of a key after
# it was inserted into the `Hash` may lead to undefined behaviour. This can be
# restored by re-indexing the hash with `#rehash`.
class Hash(K, V)
  include Enumerable({K, V})
  include Iterable({K, V})

  # ===========================================================================
  # Overall explanation of the algorithm
  # ===========================================================================
  #
  # Hash implements an open addressing collision resolution method:
  # https://en.wikipedia.org/wiki/Open_addressing
  #
  # The collision resolution is done using Linear Probing:
  # https://en.wikipedia.org/wiki/Linear_probing
  #
  # The algorithm is partially based on Ruby's one but they are not exactly the same:
  # https://github.com/ruby/ruby/blob/a4c09342a2219a8374240ef8d0ca86abe287f715/st.c#L1-L101
  #
  # There are two main data structures:
  #
  # - @entries:
  #     A contiguous buffer (Pointer) of hash entries (Entry) in the order
  #     they were inserted. This makes it possible for Hash to preserve
  #     order of insertion.
  #     An entry holds a key-value pair together with the key's hash code.
  #     An entry can also be marked as deleted. This is accomplished by using
  #     0 as the hash code value. Because 0 is a valid hash code value, when
  #     computing the key's hash code if it's 0 then it's replaced by another
  #     value (UInt32::MAX). The alternative would be to use a boolean but
  #     that involves more memory allocated and worse performance.
  # - @indices:
  #     A buffer of indices into the @entries buffer.
  #     An index might mean it's empty. We could use -1 for this but because
  #     of an optimization we'll explain later we use 0, and all other values
  #     represent indices which are 1 less than their actual value (so value
  #     3 means index 2).
  #     When a key-value pair is inserted we first find the key's hash and
  #     then fit it (by modulo) into the indices buffer size. For example,
  #     assuming we are inserting a new key-value pair with key "hello",
  #     if the indices size is 128, the key is "hello" and its hash is
  #     987 then fitting it into 128 is (987 % 128) gives 91. Lets also
  #     assume there are already 3 entries in @entries. We go ahead an add
  #     a new entry at index 3, and at position 91 in @indices we store 3
  #     (well, actually 4 because we store 1 more than the actual index
  #     because 0 means empty, as explained above).
  #
  # Open addressing means that if, in the example above, we go and try to
  # insert another key with a hash that will be placed in the same position
  # in indices (let's say, 91 again), because it's occupied we will insert
  # it into the next non-empty slot. We try with 92. If it's empty we again
  # go and insert it intro `@entries` and store the index at 92 (continuing
  # with the previous example we would store the value 4).
  #
  # If we keep the size of @indices the same as @entries it means that in the worse
  # case @indices is full and when finding a match we have to traverse it all,
  # which is bad. That's why we always make the size of @indices at least twice
  # as big as the size of @entries, so the non-empty indices will tend to be
  # spread apart with empty indices in the middle.
  #
  # Also, we always keep the sizes of `@indices` and `@entries` (`indices_size` / 2)
  # powers of 2, with the smallest size of `@indices` being 8 (and thus of
  # `@entries` being 4).
  #
  # The size of `@indices` is stored as a number that has to be powered by 2 in
  # `@indices_size_pow2`. For example if `@indices_size_pow2` is 3 then the actual
  # size is 2**3 = 8.
  #
  # Next comes the optimizations.
  #
  # The first one is that for an empty hash we don't allocate `@entries`
  # nor `@indices`, and there are a few checks against these when adding
  # and fetching elements. Sometimes hashes are created empty and remain empty
  # for some time or for the duration of the program when not used, and this
  # helps save some memory.
  #
  # The second optimization is that for small hashes (less or equal to 16 elements)
  # we don't allocate `@indices` and just perform a linear scan on `@entries`.
  # This is an heuristic but in practice it's faster to search linearly in small
  # hashes. There's another heuristic here: if we have less than or equal to 8
  # elements we just compare values when doing the linear scan. If we have between
  # 9 and 16 we first compute the hash code of the key and compare the hash codes
  # first (at this point computing the hash code plus comparing them might become
  # cheaper than doing a full comparison each time). This optimization also exists
  # in the Ruby implementation (though it seems hash values are always compared).
  #
  # A third optimization is in the way `@indices` is allocated: when the number
  # of entries is less than or equal to 128 (2 ** 8 / 2) the indexes values will range between
  # 0 and 128. That means we can use `Pointer(UInt8)` as the type of `@indices`.
  # (we can't do it for ranges between 0 and 256 because we need a value that means
  # "empty"). Similarly, for ranges between 128 and 32768 (2 ** 16 / 2) we can use
  # `Pointer(UInt16)`. This saves some memory (and the performance difference is
  # noticeable). We store the bytesize of the `@indices` buffer in `@indices_bytesize`
  # with values 1 (UInt8), 2 (UInt16) or 4 (UInt32). This optimization also exists
  # in the Ruby implementation.
  #
  # Another optimization is, when fitting a value inside the range of `@indices`,
  # to use masking (value & mask) instead of `remainder` or `%`, which apparently
  # are much slower. This optimization also exists in the Ruby implementation.
  #
  # We also keep track of the number of deleted entries (`@deleted_count`). When an
  # entry is deleted we just mark it as deleted by using the special hash value 0.
  # Only when the hash needs to be resized we do something with this instance variable:
  # if we have many deleted entries (at least as many as the number of non-deleted
  # entries) we compact the map and avoid a resize. Otherwise we remove the non-deleted
  # entries but also resize both the `@entries` and `@indices` buffer. This probably
  # avoids an edge case where one deletes and inserts an element and there is a constant
  # shift of the buffer (expensive).
  #
  # There might be other optimizations to try out, like not using Linear Probing,
  # but for now this implementation is much faster than the old one which used
  # linked lists (closed addressing).
  #
  # All methods that deal with this implementation come after the constructors.
  # Then all other methods use the internal methods, usually using other high-level
  # methods.

  # The index of the first non-deleted entry in `@entries`.
  # This is useful to support `shift`: instead of marking an entry
  # as deleted and then always having to ignore it we just increment this
  # variable and always start iterating from it.
  # The invariant of `@first` always pointing to a non-deleted entry holds
  # (unless `@size` is 0) and is guaranteed because of how
  # `delete_and_update_counts` is implemented.
  @first : Int32 = 0

  # The buffer of entries.
  # Might be null if the hash is empty at the very beginning.
  # Has always the size of `indices_size` / 2.
  @entries : Pointer(Entry(K, V))

  # The buffer of indices into entries. Its size is given by `@indices_size_pow2`.
  # Might be null if the hash is empty at the very beginning or when the hash
  # size is less than or equal to 16.
  # Could be a Slice but this way we might save a few bounds checking.
  @indices : Pointer(UInt8)

  # The number of actual entries in the hash.
  # Exposed to the user via the `size` getter.
  @size : Int32

  # The number of deleted entries.
  # Resets to zero when the hash resizes.
  @deleted_count : Int32

  # The actual type of `@indices`:
  # - 1 means `Pointer(UInt8)`
  # - 2 means `Pointer(UInt16)`
  # - 4 means `Pointer(UInt32)`
  @indices_bytesize : Int8

  # The size of `@indices` given as a power of 2.
  # For example if it's 4 it means 2**4 so size 16.
  # Can be zero when hash is totally empty.
  # Otherwise guaranteed to be at least 3.
  @indices_size_pow2 : UInt8

  # Whether to compare objects using `object_id`.
  @compare_by_identity : Bool = false

  # The optional block that triggers on non-existing keys.
  @block : (self, K -> V)?

  # Creates a new empty `Hash`.
  def initialize
    @entries = Pointer(Entry(K, V)).null
    @indices = Pointer(UInt8).null
    @indices_size_pow2 = 0
    @size = 0
    @deleted_count = 0
    @block = nil
    @indices_bytesize = 1
  end

  # Creates a new empty `Hash` with a *block* for handling missing keys.
  #
  # ```
  # proc = ->(hash : Hash(String, Int32), key : String) { hash[key] = key.size }
  # hash = Hash(String, Int32).new(proc)
  #
  # hash.size   # => 0
  # hash["foo"] # => 3
  # hash.size   # => 1
  # hash["bar"] = 10
  # hash["bar"] # => 10
  # ```
  #
  # The *initial_capacity* is useful to avoid unnecessary reallocations
  # of the internal buffer in case of growth. If the number of elements
  # a hash will hold is known, the hash should be initialized with that
  # capacity for improved performance. Otherwise, the default is 8.
  # Inputs lower than 8 are ignored.
  def initialize(block : (Hash(K, V), K -> V)? = nil, *, initial_capacity = nil)
    initial_capacity = (initial_capacity || 0).to_i32

    # Same as the empty hash case
    # (but this constructor is a bit more expensive in terms of code execution).
    if initial_capacity == 0
      @entries = Pointer(Entry(K, V)).null
      @indices = Pointer(UInt8).null
      @indices_size_pow2 = 0
      @indices_bytesize = 1
    else
      # Translate initial capacity to the nearest power of 2, but keep it a minimum of 8.
      if initial_capacity < 8
        initial_entries_size = 8
      else
        initial_entries_size = Math.pw2ceil(initial_capacity)
      end

      # Because we always keep indice_size >= entries_size * 2
      initial_indices_size = initial_entries_size * 2

      @entries = malloc_entries(initial_entries_size)

      # Check if we can avoid allocating the `@indices` buffer for
      # small hashes.
      if initial_indices_size > MAX_INDICES_SIZE_LINEAR_SCAN
        @indices_bytesize = compute_indices_bytesize(initial_indices_size)
        @indices = malloc_indices(initial_indices_size)
      else
        @indices = Pointer(UInt8).null
        @indices_bytesize = 1
      end

      @indices_size_pow2 = initial_indices_size.bit_length.to_u8 - 1
    end

    @size = 0
    @deleted_count = 0
    @block = block
  end

  # Creates a new empty `Hash` with a *block* that handles missing keys.
  #
  # ```
  # hash = Hash(String, Int32).new do |hash, key|
  #   hash[key] = key.size
  # end
  #
  # hash.size   # => 0
  # hash["foo"] # => 3
  # hash.size   # => 1
  # hash["bar"] = 10
  # hash["bar"] # => 10
  # ```
  #
  # The *initial_capacity* is useful to avoid unnecessary reallocations
  # of the internal buffer in case of growth. If the number of elements
  # a hash will hold is known, the hash should be initialized with that
  # capacity for improved performance. Otherwise, the default is 8.
  # Inputs lower than 8 are ignored.
  def self.new(initial_capacity = nil, &block : (Hash(K, V), K -> V))
    new block, initial_capacity: initial_capacity
  end

  # Creates a new empty `Hash` where the *default_value* is returned if a key is missing.
  #
  # ```
  # inventory = Hash(String, Int32).new(0)
  # inventory["socks"] = 3
  # inventory["pickles"] # => 0
  # ```
  #
  # NOTE: The default value is passed by reference:
  # ```
  # arr = [1, 2, 3]
  # hash = Hash(String, Array(Int32)).new(arr)
  # hash["3"][1] = 4
  # arr # => [1, 4, 3]
  # ```
  #
  # The *initial_capacity* is useful to avoid unnecessary reallocations
  # of the internal buffer in case of growth. If the number of elements
  # a hash will hold is known, the hash should be initialized with that
  # capacity for improved performance. Otherwise, the default is 8.
  # Inputs lower than 8 are ignored.
  def self.new(default_value : V, initial_capacity = nil)
    new(initial_capacity: initial_capacity) { default_value }
  end

  # ===========================================================================
  # Internal implementation starts
  # ===========================================================================

  # Maximum number of `indices_size` for which we do a linear scan
  # (maximum of 16 entries in `@entries`)
  private MAX_INDICES_SIZE_LINEAR_SCAN = 32

  # Maximum number of `indices_size` for which we can represent `@indices`
  # as Pointer(UInt8).
  private MAX_INDICES_BYTESIZE_1 = 256

  # Maximum number of `indices_size` for which we can represent `@indices`
  # as Pointer(UInt16).
  private MAX_INDICES_BYTESIZE_2 = 65536

  # Inserts or updates a key-value pair.
  # Returns an `Entry` if it was updated, otherwise `nil`.
  private def upsert(key, value) : Entry(K, V)?
    # Empty hash table so only initialize entries for now
    if @entries.null?
      @indices_size_pow2 = 3
      @entries = malloc_entries(4)
    end

    hash = key_hash(key)

    # No indices allocated yet so try to do a linear scan
    if @indices.null?
      # Try to do an update by doing a linear scan
      updated_entry = update_linear_scan(key, value, hash)
      return updated_entry if updated_entry

      # If we still have space, add an entry.
      if !entries_full?
        add_entry_and_increment_size(hash, key, value)
        return nil
      end

      # No more space so we need to do a resize
      resize

      # Now, it could happen that we are still with less than 16 elements
      # and so `@indices` will be null, in which case we only need to
      # add the key-value pair at the end of the `@entries` buffer.
      if @indices.null?
        add_entry_and_increment_size(hash, key, value)
        return nil
      end

      # Otherwise `@indices` became non-null which means we can't do
      # a linear scan anymore.
    end

    # Fit the hash value into an index in `@indices`
    index = fit_in_indices(hash)

    while true
      entry_index = get_index(index)

      # If the index entry is empty...
      if entry_index == -1
        # If we reached the maximum in `@entries` it's time to resize
        if entries_full?
          resize
          # We have to fit the hash into an index in `@indices` again, and try again
          index = fit_in_indices(hash)
          next
        end

        # We have free space: store the index and then insert the entry
        set_index(index, entries_size)
        add_entry_and_increment_size(hash, key, value)
        return nil
      end

      # We found a non-empty slot, let's see if the key we have matches
      entry = get_entry(entry_index)
      if entry_matches?(entry, hash, key)
        # If it does we just update the entry
        set_entry(entry_index, Entry(K, V).new(hash, key, value))
        return entry
      else
        # Otherwise we have to keep looking...
        index = next_index(index)
      end
    end
  end

  # Inserts a key-value pair. Assumes that the given key doesn't exist.
  private def insert_new(key, value)
    # Unless otherwise noted, this body should be identical to `#upsert`

    if @entries.null?
      @indices_size_pow2 = 3
      @entries = malloc_entries(4)
    end

    hash = key_hash(key)

    if @indices.null?
      # don't call `#update_linear_scan` here

      if !entries_full?
        add_entry_and_increment_size(hash, key, value)
        return
      end

      resize

      if @indices.null?
        add_entry_and_increment_size(hash, key, value)
        return
      end
    end

    index = fit_in_indices(hash)

    while true
      entry_index = get_index(index)

      if entry_index == -1
        if entries_full?
          resize
          index = fit_in_indices(hash)
          next
        end

        set_index(index, entries_size)
        add_entry_and_increment_size(hash, key, value)
        return
      end

      # don't call `#get_entry` and `#entry_matches?` here

      index = next_index(index)
    end
  end

  # Tries to update a key-value-hash triplet by doing a linear scan.
  # Returns an old `Entry` if it was updated, otherwise `nil`.
  private def update_linear_scan(key, value, hash) : Entry(K, V)?
    # Just do a linear scan...
    each_entry_with_index do |entry, index|
      if entry_matches?(entry, hash, key)
        set_entry(index, Entry(K, V).new(entry.hash, entry.key, value))
        return entry
      end
    end

    nil
  end

  # Implementation of deleting a key.
  # Returns the deleted Entry, if it existed, `nil` otherwise.
  private def delete_impl(key) : Entry(K, V)?
    # Empty hash table, nothing to do
    if @indices_size_pow2 == 0
      return nil
    end

    hash = key_hash(key)

    # No indices allocated yet so do linear scan
    if @indices.null?
      return delete_linear_scan(key, hash)
    end

    # Fit hash into `@indices` size
    index = fit_in_indices(hash)
    while true
      entry_index = get_index(index)

      # If we find an empty index slot, there's no such key
      if entry_index == -1
        return nil
      end

      # We found a non-empty slot, let's see if the key we have matches
      entry = get_entry(entry_index)
      if entry_matches?(entry, hash, key)
        delete_entry_and_update_counts(entry_index)
        return entry
      else
        # If it doesn't, check the next index...
        index = next_index(index)
      end
    end
  end

  # Delete by doing a linear scan over `@entries`.
  # Returns the deleted Entry, if it existed, `nil` otherwise.
  private def delete_linear_scan(key, hash) : Entry(K, V)?
    each_entry_with_index do |entry, index|
      if entry_matches?(entry, hash, key)
        delete_entry_and_update_counts(index)
        return entry
      end
    end

    nil
  end

  # Finds an entry with the given key.
  protected def find_entry(key) : Entry(K, V)?
    if entry_index = find_entry_with_index(key)
      return entry_index[0]
    end
  end

  # Finds an entry (and its index) with the given key.
  protected def find_entry_with_index(key) : {Entry(K, V), Int32}?
    # Empty hash table so there's no way it's there
    if @indices_size_pow2 == 0
      return nil
    end

    # No indices allocated yet so do linear scan
    if @indices.null?
      return find_entry_with_index_linear_scan(key)
    end

    hash = key_hash(key)

    # Fit hash into `@indices` size
    index = fit_in_indices(hash)
    while true
      entry_index = get_index(index)

      # If we find an empty index slot, there's no such key
      if entry_index == -1
        return nil
      end

      # We found a non-empty slot, let's see if the key we have matches
      entry = get_entry(entry_index)
      if entry_matches?(entry, hash, key)
        # It does!
        return entry, entry_index
      else
        # Nope, move on to the next slot
        index = next_index(index)
      end
    end
  end

  # Finds an Entry with the given key by doing a linear scan.
  private def find_entry_with_index_linear_scan(key) : {Entry(K, V), Int32}?
    # If we have less than 8 elements we avoid computing the hash
    # code and directly compare the keys (might be cheaper than
    # computing a hash code of a complex structure).
    if entries_size <= 8
      each_entry_with_index do |entry, index|
        return entry, index if entry_matches?(entry, key)
      end
    else
      hash = key_hash(key)
      each_entry_with_index do |entry, index|
        return entry, index if entry_matches?(entry, hash, key)
      end
    end

    nil
  end

  # Tries to resize the hash table in the condition that there are
  # no more available entries to add.
  # Might not result in a resize if there are many entries marked as
  # deleted. In that case the entries table is simply compacted.
  # However, in case of a resize deleted entries are also compacted.
  private def resize : Nil
    # Only do an actual resize (grow `@entries` buffer) if we don't
    # have many deleted elements.
    if @deleted_count < @size
      # First grow `@entries`
      realloc_entries(indices_size)
      double_indices_size

      # If we didn't have `@indices` and we still don't have 16 entries
      # we keep doing linear scans (not using `@indices`)
      if @indices.null? && indices_size <= MAX_INDICES_SIZE_LINEAR_SCAN
        return
      end

      # Otherwise, we must either start using `@indices`
      # or grow the ones we had.
      @indices_bytesize = compute_indices_bytesize(indices_size)
      if @indices.null?
        @indices = malloc_indices(indices_size)
      else
        @indices = realloc_indices(indices_size)
      end
    end

    do_compaction

    # After compaction we no longer have deleted entries
    @deleted_count = 0

    # And the first valid entry is the first one
    @first = 0
  end

  # Compacts `@entries` (only keeps non-deleted ones) and rebuilds `@indices.`
  # If `rehash` is `true` then hash values inside each `Entry` will be recomputed.
  private def do_compaction(rehash : Bool = false) : Nil
    # `@indices` might still be null if we are compacting in the case where
    # we are still doing a linear scan (and we had many deleted elements)
    if @indices.null?
      has_indices = false
    else
      # If we do have indices we must clear them because we'll rebuild
      # them from scratch
      has_indices = true
      clear_indices
    end

    # Here we traverse the `@entries` and compute their new index in `@indices`
    # while moving non-deleted entries to the beginning (compaction).
    new_entry_index = 0
    each_entry_with_index do |entry, entry_index|
      if rehash
        # When rehashing we always have to copy the entry
        entry_hash = key_hash(entry.key)
        set_entry(new_entry_index, Entry(K, V).new(entry_hash, entry.key, entry.value))
      else
        # First we move the entry to its new index (if we need to do that)
        entry_hash = entry.hash
        set_entry(new_entry_index, entry) if entry_index != new_entry_index
      end

      if has_indices
        # Then we try to find an empty index slot
        # (we should find one now that we have more space)
        index = fit_in_indices(entry_hash)
        until get_index(index) == -1
          index = next_index(index)
        end
        set_index(index, new_entry_index)
      end

      new_entry_index += 1
    end

    # We have to mark entries starting from the final new index
    # as deleted so the GC can collect them.
    entries_to_clear = entries_size - new_entry_index
    if entries_to_clear > 0
      (entries + new_entry_index).clear(entries_to_clear)
    end
  end

  # After this it's 1 << 28, and with entries being Int32
  # (4 bytes) it's 1 << 30 of actual bytesize and the
  # next value would be 1 << 31 which overflows `Int32`.
  private MAXIMUM_INDICES_SIZE = 1 << 28

  # Doubles the value of `@indices_size` but first checks
  # whether the maximum hash size is reached.
  private def double_indices_size : Nil
    if indices_size == MAXIMUM_INDICES_SIZE
      raise "Maximum Hash size reached"
    end

    @indices_size_pow2 += 1
  end

  # Implementation of clearing the hash table.
  private def clear_impl : Nil
    # We _could_ set all buffers to null and start like in the
    # empty case.
    # However, it might happen that a user calls clear and then inserts
    # elements in a loop. In that case each insert after clear will cause
    # a new memory allocation and that's not good.
    # Just clearing the buffers might retain some memory but it
    # avoids a possible constant reallocation (which is slower).
    clear_entries unless @entries.null?
    clear_indices unless @indices.null?
    @size = 0
    @deleted_count = 0
    @first = 0
  end

  # Initializes a `dup` copy from the contents of `other`.
  protected def initialize_dup(other)
    initialize_compare_by_identity(other)
    initialize_default_block(other)

    return if other.empty?

    initialize_dup_entries(other)
    initialize_copy_non_entries_vars(other)
  end

  # Initializes a `clone` copy from the contents of `other`.
  protected def initialize_clone(other)
    initialize_compare_by_identity(other)
    initialize_default_block(other)

    return if other.empty?

    initialize_clone_entries(other)
    initialize_copy_non_entries_vars(other)
  end

  private def initialize_compare_by_identity(other)
    compare_by_identity if other.compare_by_identity?
  end

  private def initialize_default_block(other)
    @block = other.@block
  end

  # Initializes `@entries` for a dup copy.
  # Here we only need to duplicate the buffer.
  private def initialize_dup_entries(other)
    return if other.@entries.null?

    @entries = malloc_entries(other.entries_capacity)

    # Note that we only need to copy `entries_size` which
    # are the effective entries in use.
    @entries.copy_from(other.@entries, other.entries_size)
  end

  # Initializes `@entries` for a clone copy.
  # Here we need to copy entries while cloning their values.
  private def initialize_clone_entries(other)
    return if other.@entries.null?

    @entries = malloc_entries(other.entries_capacity)

    other.each_entry_with_index do |entry, index|
      set_entry(index, entry.clone)
    end
  end

  # Initializes all variables other than `@entries` and `@block` for a copy.
  private def initialize_copy_non_entries_vars(other)
    @indices_bytesize = other.@indices_bytesize
    @first = other.@first
    @size = other.@size
    @deleted_count = other.@deleted_count
    @indices_size_pow2 = other.@indices_size_pow2

    unless other.@indices.null?
      @indices = malloc_indices(other.indices_size)
      @indices.copy_from(other.@indices, indices_malloc_size(other.indices_size))
    end
  end

  # Gets from `@indices` at the given `index`.
  # Returns the index in `@entries` or `-1` if the slot is empty.
  private def get_index(index : Int32) : Int32
    # Check what we have: UInt8, Int16 or UInt32 buckets
    value = case @indices_bytesize
            when 1
              @indices[index].to_i32!
            when 2
              @indices.as(UInt16*)[index].to_i32!
            else
              @indices.as(UInt32*)[index].to_i32!
            end

    # Because we increment the value by one when we store the value
    # here we have to subtract one
    value - 1
  end

  # Sets `@indices` at `index` with the given value.
  private def set_index(index, value) : Nil
    # We actually store 1 more than the value because 0 means empty.
    value += 1

    # We also have to see what we have: UInt8, UInt16 or UInt32 buckets.
    case @indices_bytesize
    when 1
      @indices[index] = value.to_u8!
    when 2
      @indices.as(UInt16*)[index] = value.to_u16!
    else
      @indices.as(UInt32*)[index] = value.to_u32!
    end
  end

  # Returns the capacity of `@indices`.
  protected def indices_size
    1 << @indices_size_pow2
  end

  # Computes what bytesize we'll store in `@indices` according to its size
  private def compute_indices_bytesize(size) : Int8
    case
    when size <= MAX_INDICES_BYTESIZE_1
      1_i8
    when size <= MAX_INDICES_BYTESIZE_2
      2_i8
    else
      4_i8
    end
  end

  # Allocates `size` number of indices for `@indices`.
  private def malloc_indices(size)
    Pointer(UInt8).malloc(indices_malloc_size(size))
  end

  # The actual number of bytes needed to allocate `@indices`.
  private def indices_malloc_size(size)
    size * @indices_bytesize
  end

  # Reallocates `size` number of indices for `@indices`.
  private def realloc_indices(size)
    @indices.realloc(indices_malloc_size(size))
  end

  # Marks all existing indices as empty.
  private def clear_indices : Nil
    @indices.clear(indices_malloc_size(indices_size))
  end

  # Returns the entry in `@entries` at `index`.
  private def get_entry(index) : Entry(K, V)
    @entries[index]
  end

  # Sets the entry in `@entries` at `index`.
  private def set_entry(index, value) : Nil
    @entries[index] = value
  end

  # Adds an entry at the end and also increments this hash's size.
  private def add_entry_and_increment_size(hash, key, value) : Nil
    set_entry(entries_size, Entry(K, V).new(hash, key, value))
    @size += 1
  end

  # Marks an entry in `@entries` at `index` as deleted
  # *without* modifying any counters (`@size` and `@deleted_count`).
  private def delete_entry(index) : Nil
    set_entry(index, Entry(K, V).deleted)
  end

  # Marks an entry in `@entries` at `index` as deleted
  # and updates the `@size` and `@deleted_count` counters.
  private def delete_entry_and_update_counts(index) : Nil
    delete_entry(index)
    @size -= 1
    @deleted_count += 1

    # If we are deleting the first entry there are some
    # more optimizations we can do
    return if index != @first

    # If the Hash is now empty then the first effective
    # entry starts right after all the deleted ones.
    if @size == 0
      @first = @deleted_count
    else
      # Otherwise, we bump `@first` and keep bumping it
      # until we find a non-deleted entry. It's guaranteed
      # that this loop will end because `@size != 0` so
      # there will be a non-deleted entry.
      # It's better to skip the deleted entries once here
      # and not every next time someone accesses the Hash.
      # With this we also keep the invariant that `@first`
      # always points to the first non-deleted entry.
      @first += 1
      while @entries[@first].deleted?
        @first += 1
      end
    end
  end

  # Returns true if there's no place for new entries without doing a resize.
  private def entries_full? : Bool
    entries_size == entries_capacity
  end

  # Yields each non-deleted Entry with its index inside `@entries`.
  protected def each_entry_with_index(&) : Nil
    return if @size == 0

    @first.upto(entries_size - 1) do |i|
      entry = get_entry(i)
      yield entry, i unless entry.deleted?
    end
  end

  # Allocates `size` number of entries for `@entries`.
  private def malloc_entries(size)
    Pointer(Entry(K, V)).malloc(size)
  end

  private def realloc_entries(size)
    @entries = @entries.realloc(size)
  end

  # Marks all existing entries as deleted
  private def clear_entries
    @entries.clear(entries_capacity)
  end

  # Computes the next index in `@indices`, needed when an index is not empty.
  private def next_index(index : Int32) : Int32
    fit_in_indices(index + 1)
  end

  # Fits a value inside the range of `@indices`
  private def fit_in_indices(value) : Int32
    # We avoid doing modulo (`%` or `remainder`) because it's much
    # slower than `<<` + `-` + `&`.
    # For example if `@indices_size_pow2` is 8 then `indices_size`
    # will be 256 (1 << 8) and the mask we use is 0xFF, which is 256 - 1.
    (value & ((1_u32 << @indices_size_pow2) - 1)).to_i32!
  end

  # Returns the first `Entry` or `nil` if non exists.
  private def first_entry?
    # We always make sure that `@first` points to the first
    # non-deleted entry, so `@entries[@first]` is guaranteed
    # to be non-deleted.
    @size == 0 ? nil : @entries[@first]
  end

  # Returns the first `Entry` or `nil` if non exists.
  private def last_entry?
    return nil if @size == 0

    (entries_size - 1).downto(@first).each do |i|
      entry = get_entry(i)
      return entry unless entry.deleted?
    end

    # Might happen if the Hash is modified concurrently
    nil
  end

  protected getter entries

  # Returns the total number of existing entries, including
  # deleted and non-deleted ones.
  protected def entries_size
    @size + @deleted_count
  end

  # Returns the capacity of `@entries`.
  protected def entries_capacity
    indices_size // 2
  end

  # Computes the hash of a key.
  private def key_hash(key)
    if @compare_by_identity && key.responds_to?(:object_id)
      hash = key.object_id.hash.to_u32!
    else
      hash = key.hash.to_u32!
    end
    hash == 0 ? UInt32::MAX : hash
  end

  private def entry_matches?(entry, hash, key)
    # Tiny optimization: for these primitive types it's faster to just
    # compare the key instead of comparing the hash and the key.
    # We still have to skip hashes with value 0 (means deleted).
    {% if K == Bool ||
            K == Char ||
            K == Symbol ||
            K < Number::Primitive ||
            K < Enum %}
      entry.key == key && entry.hash != 0_u32
    {% else %}
      entry.hash == hash && entry_matches?(entry, key)
    {% end %}
  end

  private def entry_matches?(entry, key)
    entry_key = entry.key

    if @compare_by_identity
      if entry_key.responds_to?(:object_id)
        if key.responds_to?(:object_id)
          entry_key.object_id == key.object_id
        else
          false
        end
      elsif key.responds_to?(:object_id)
        # because entry_key doesn't respond to :object_id
        false
      else
        entry_key == key
      end
    else
      entry_key == key
    end
  end

  # ===========================================================================
  # Internal implementation ends
  # ===========================================================================

  # Returns the number of elements in this Hash.
  getter size : Int32

  # Makes this hash compare keys using their object identity (`object_id)`
  # for types that define such method (`Reference` types, but also structs that
  # might wrap other `Reference` types and delegate the `object_id` method to them).
  #
  # ```
  # h1 = {"foo" => 1, "bar" => 2}
  # h1["fo" + "o"]? # => 1
  #
  # h1.compare_by_identity
  # h1.compare_by_identity? # => true
  # h1["fo" + "o"]?         # => nil # not the same String instance
  # ```
  def compare_by_identity : self
    @compare_by_identity = true
    rehash
    self
  end

  # Returns `true` of this Hash is comparing keys by `object_id`.
  #
  # See `compare_by_identity`.
  getter? compare_by_identity : Bool

  # Sets the value of *key* to the given *value*.
  #
  # ```
  # h = {} of String => String
  # h["foo"] = "bar"
  # h["foo"] # => "bar"
  # ```
  def []=(key : K, value : V) : V
    upsert(key, value)
    value
  end

  # Sets the value of *key* to the given *value*.
  #
  # If a value already exists for *key*, that (old) value is returned.
  # Otherwise the given block is invoked with *key* and its value is returned.
  #
  # ```
  # h = {} of Int32 => String
  # h.put(1, "one") { "didn't exist" } # => "didn't exist"
  # h.put(1, "uno") { "didn't exist" } # => "one"
  # h.put(2, "two") { |key| key.to_s } # => "2"
  # h                                  # => {1 => "one", 2 => "two"}
  # ```
  def put(key : K, value : V, &)
    updated_entry = upsert(key, value)
    updated_entry ? updated_entry.value : yield key
  end

  # Sets the value of *key* to the given *value*, unless a value for *key*
  # already exists.
  #
  # If a value already exists for *key*, that (old) value is returned.
  # Otherwise *value* is returned.
  #
  # ```
  # h = {} of Int32 => Array(String)
  # h.put_if_absent(1, "one") # => "one"
  # h.put_if_absent(1, "uno") # => "one"
  # h.put_if_absent(2, "two") # => "two"
  # h                         # => {1 => "one", 2 => "two"}
  # ```
  def put_if_absent(key : K, value : V) : V
    put_if_absent(key) { value }
  end

  # Sets the value of *key* to the value returned by the given block, unless a
  # value for *key* already exists.
  #
  # If a value already exists for *key*, that (old) value is returned.
  # Otherwise the given block is invoked with *key* and its value is returned.
  #
  # ```
  # h = {} of Int32 => Array(String)
  # h.put_if_absent(1) { |key| [key.to_s] } # => ["1"]
  # h.put_if_absent(1) { [] of String }     # => ["1"]
  # h.put_if_absent(2) { |key| [key.to_s] } # => ["2"]
  # h                                       # => {1 => ["1"], 2 => ["2"]}
  # ```
  #
  # `hash.put_if_absent(key) { value }` is a more performant alternative to
  # `hash[key] ||= value` that also works correctly when the hash may contain
  # falsey values.
  def put_if_absent(key : K, & : K -> V) : V
    if entry = find_entry(key)
      entry.value
    else
      value = yield key
      insert_new(key, value)
      value
    end
  end

  # Updates the current value of *key* with the value returned by the given block
  # (the current value is used as input for the block).
  #
  # If no entry for *key* is present, but there's a default value (or default block)
  # then that default value is used as input for the given block.
  #
  # If no entry for *key* is present and the hash has no default value, it raises `KeyError`.
  #
  # It returns the value used as input for the given block
  # (ie. the old value if key present, or the default value)
  #
  # ```
  # h = {"a" => 0, "b" => 1}
  # h.update("b") { |v| v + 41 } # => 1
  # h["b"]                       # => 42
  #
  # h = Hash(String, Int32).new(40)
  # h.update("foo") { |v| v + 2 } # => 40
  # h["foo"]                      # => 42
  #
  # h = {} of String => Int32
  # h.update("a") { 42 } # raises KeyError
  # ```
  #
  # See `#transform_values!` for updating *all* the values.
  def update(key : K, & : V -> V) : V
    if entry_index = find_entry_with_index(key)
      entry, index = entry_index
      set_entry(index, Entry(K, V).new(entry.hash, entry.key, yield entry.value))
      entry.value
    elsif block = @block
      default_value = block.call(self, key)
      insert_new(key, yield default_value)
      default_value
    else
      raise KeyError.new "Missing hash key: #{key.inspect}"
    end
  end

  # Returns the value for the key given by *key*.
  # If not found, returns the default value given by `Hash.new`, otherwise raises `KeyError`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h["foo"] # => "bar"
  #
  # h = Hash(String, String).new("bar")
  # h["foo"] # => "bar"
  #
  # h = Hash(String, String).new { "bar" }
  # h["foo"] # => "bar"
  #
  # h = Hash(String, String).new
  # h["foo"] # raises KeyError
  # ```
  def [](key)
    fetch(key) do
      if (block = @block) && key.is_a?(K)
        block.call(self, key.as(K))
      else
        raise KeyError.new "Missing hash key: #{key.inspect}"
      end
    end
  end

  # Returns the value for the key given by *key*.
  # If not found, returns `nil`. This ignores the default value set by `Hash.new`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h["foo"]? # => "bar"
  # h["bar"]? # => nil
  #
  # h = Hash(String, String).new("bar")
  # h["foo"]? # => nil
  # ```
  def []?(key)
    fetch(key, nil)
  end

  # Traverses the depth of a structure and returns the value.
  # Returns `nil` if not found.
  #
  # ```
  # h = {"a" => {"b" => [10, 20, 30]}}
  # h.dig? "a", "b" # => [10, 20, 30]
  # h.dig? "a", "x" # => nil
  # ```
  def dig?(key : K, *subkeys)
    if (value = self[key]?) && value.responds_to?(:dig?)
      value.dig?(*subkeys)
    end
  end

  # :nodoc:
  def dig?(key : K)
    self[key]?
  end

  # Traverses the depth of a structure and returns the value, otherwise
  # raises `KeyError`.
  #
  # ```
  # h = {"a" => {"b" => [10, 20, 30]}}
  # h.dig "a", "b" # => [10, 20, 30]
  # h.dig "a", "x" # raises KeyError
  # ```
  def dig(key : K, *subkeys)
    if (value = self[key]) && value.responds_to?(:dig)
      return value.dig(*subkeys)
    end
    raise KeyError.new "Hash value not diggable for key: #{key.inspect}"
  end

  # :nodoc:
  def dig(key : K)
    self[key]
  end

  # Returns `true` when key given by *key* exists, otherwise `false`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.has_key?("foo") # => true
  # h.has_key?("bar") # => false
  # ```
  def has_key?(key) : Bool
    !!find_entry(key)
  end

  # Returns `true` when value given by *value* exists, otherwise `false`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.has_value?("foo") # => false
  # h.has_value?("bar") # => true
  # ```
  def has_value?(val) : Bool
    each_value do |value|
      return true if value == val
    end
    false
  end

  # Returns the value for the key given by *key*, or when not found the value given by *default*.
  # This ignores the default value set by `Hash.new`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.fetch("foo", "foo") # => "bar"
  # h.fetch("bar", "foo") # => "foo"
  # ```
  def fetch(key, default)
    fetch(key) { default }
  end

  # Returns the value for the key given by *key*, or when not found calls the given block with the key.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.fetch("foo") { "default value" }  # => "bar"
  # h.fetch("bar") { "default value" }  # => "default value"
  # h.fetch("bar") { |key| key.upcase } # => "BAR"
  # ```
  def fetch(key, &)
    entry = find_entry(key)
    entry ? entry.value : yield key
  end

  # Returns a tuple populated with the values of the given *keys*, with the same order.
  # Raises if a key is not found.
  #
  # ```
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.values_at("a", "c") # => {1, 3}
  # ```
  def values_at(*keys : K)
    keys.map { |index| self[index] }
  end

  # Returns a key with the given *value*, else raises `KeyError`.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.key_for("bar")    # => "foo"
  # hash.key_for("qux")    # => "baz"
  # hash.key_for("foobar") # raises KeyError (Missing hash key for value: foobar)
  # ```
  def key_for(value) : K
    key_for(value) { raise KeyError.new "Missing hash key for value: #{value}" }
  end

  # Returns a key with the given *value*, else `nil`.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.key_for?("bar")    # => "foo"
  # hash.key_for?("qux")    # => "baz"
  # hash.key_for?("foobar") # => nil
  # ```
  def key_for?(value) : K?
    key_for(value) { nil }
  end

  # Returns a key with the given *value*, else yields *value* with the given block.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.key_for("bar") { |value| value.upcase } # => "foo"
  # hash.key_for("qux") { |value| value.upcase } # => "QUX"
  # ```
  def key_for(value, &)
    each do |k, v|
      return k if v == value
    end
    yield value
  end

  # Deletes the key-value pair and returns the value, otherwise returns `nil`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.delete("foo")     # => "bar"
  # h.fetch("foo", nil) # => nil
  # ```
  def delete(key) : V?
    delete(key) { nil }
  end

  # Deletes the key-value pair and returns the value, else yields *key* with given block.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.delete("foo") { |key| "#{key} not found" } # => "bar"
  # h.fetch("foo", nil)                          # => nil
  # h.delete("baz") { |key| "#{key} not found" } # => "baz not found"
  # ```
  def delete(key, &)
    entry = delete_impl(key)
    entry ? entry.value : yield key
  end

  # Returns `true` when hash contains no key-value pairs.
  #
  # ```
  # h = Hash(String, String).new
  # h.empty? # => true
  #
  # h = {"foo" => "bar"}
  # h.empty? # => false
  # ```
  def empty? : Bool
    @size == 0
  end

  # Calls the given block for each key-value pair and passes in the key and the value.
  #
  # ```
  # h = {"foo" => "bar"}
  #
  # h.each do |key, value|
  #   key   # => "foo"
  #   value # => "bar"
  # end
  #
  # h.each do |key_and_value|
  #   key_and_value # => {"foo", "bar"}
  # end
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each(& : {K, V} ->) : Nil
    each_entry_with_index do |entry, i|
      yield({entry.key, entry.value})
    end
  end

  # Returns an iterator over the hash entries.
  # Which behaves like an `Iterator` returning a `Tuple` consisting of the key and value types.
  #
  # ```
  # hsh = {"foo" => "bar", "baz" => "qux"}
  # iterator = hsh.each
  #
  # iterator.next # => {"foo", "bar"}
  # iterator.next # => {"baz", "qux"}
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each
    EntryIterator(K, V).new(self)
  end

  # Calls the given block for each key-value pair and passes in the key.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.each_key do |key|
  #   key # => "foo"
  # end
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each_key(& : K ->)
    each do |key, value|
      yield key
    end
  end

  # Returns an iterator over the hash keys.
  # Which behaves like an `Iterator` consisting of the key's types.
  #
  # ```
  # hsh = {"foo" => "bar", "baz" => "qux"}
  # iterator = hsh.each_key
  #
  # key = iterator.next
  # key # => "foo"
  #
  # key = iterator.next
  # key # => "baz"
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each_key
    KeyIterator(K, V).new(self)
  end

  # Calls the given block for each key-value pair and passes in the value.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.each_value do |value|
  #   value # => "bar"
  # end
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each_value(& : V ->)
    each do |key, value|
      yield value
    end
  end

  # Returns an iterator over the hash values.
  # Which behaves like an `Iterator` consisting of the value's types.
  #
  # ```
  # hsh = {"foo" => "bar", "baz" => "qux"}
  # iterator = hsh.each_value
  #
  # value = iterator.next
  # value # => "bar"
  #
  # value = iterator.next
  # value # => "qux"
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each_value
    ValueIterator(K, V).new(self)
  end

  # Returns a new `Array` with all the keys.
  #
  # ```
  # h = {"foo" => "bar", "baz" => "bar"}
  # h.keys # => ["foo", "baz"]
  # ```
  def keys : Array(K)
    to_a_impl &.key
  end

  # Returns only the values as an `Array`.
  #
  # ```
  # h = {"foo" => "bar", "baz" => "qux"}
  # h.values # => ["bar", "qux"]
  # ```
  def values : Array(V)
    to_a_impl &.value
  end

  # Returns a new `Hash` with the keys and values of this hash and *other* combined.
  # A value in *other* takes precedence over the one in this hash.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.merge({"baz" => "qux"})
  # # => {"foo" => "bar", "baz" => "qux"}
  # hash
  # # => {"foo" => "bar"}
  # ```
  def merge(other : Hash(L, W)) : Hash(K | L, V | W) forall L, W
    hash = Hash(K | L, V | W).new
    hash.merge! self
    hash.merge! other
    hash
  end

  def merge(other : Hash(L, W), & : L, V, W -> V | W) : Hash(K | L, V | W) forall L, W
    hash = Hash(K | L, V | W).new
    hash.merge! self
    hash.merge!(other) { |k, v1, v2| yield k, v1, v2 }
    hash
  end

  # Similar to `#merge`, but the receiver is modified.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.merge!({"baz" => "qux"})
  # hash # => {"foo" => "bar", "baz" => "qux"}
  # ```
  def merge!(other : Hash) : self
    other.merge_into!(self)
    self
  end

  # Adds the contents of *other* to this hash.
  # If a key exists in both hashes, the given block is called to determine the value to be used.
  # The block arguments are the key, the value in `self` and the value in *other*.
  #
  # ```
  # hash = {"a" => 100, "b" => 200}
  # other = {"b" => 254, "c" => 300}
  # hash.merge!(other) { |key, v1, v2| v1 + v2 }
  # hash # => {"a" => 100, "b" => 454, "c" => 300}
  # ```
  def merge!(other : Hash, &) : self
    other.merge_into!(self) { |k, v1, v2| yield k, v1, v2 }
    self
  end

  protected def merge_into!(other : Hash(K2, V2)) forall K2, V2
    {% unless K2 >= K && V2 >= V %}
      {% raise "#{Hash(K, V)} can't be merged into #{Hash(K2, V2)}" %}
    {% end %}

    each do |k, v|
      other[k] = v
    end
  end

  protected def merge_into!(other : Hash(K2, V2), & : K, V2, V -> V2) forall K2, V2
    {% unless K2 >= K && V2 >= V %}
      {% raise "#{Hash(K, V)} can't be merged into #{Hash(K2, V2)}" %}
    {% end %}

    each do |k, v|
      entry = other.find_entry(k)
      other[k] = entry ? yield(k, entry.value, v) : v
    end
  end

  # Returns a new hash consisting of entries for which the block is truthy.
  # ```
  # h = {"a" => 100, "b" => 200, "c" => 300}
  # h.select { |k, v| k > "a" } # => {"b" => 200, "c" => 300}
  # h.select { |k, v| v < 200 } # => {"a" => 100}
  # ```
  def select(& : K, V ->) : Hash(K, V)
    reject { |k, v| !yield(k, v) }
  end

  # Equivalent to `Hash#select` but makes modification on the current object rather than returning a new one. Returns `self`.
  def select!(& : K, V ->) : self
    reject! { |k, v| !yield(k, v) }
  end

  # Returns a new hash consisting of entries for which the block is falsey.
  # ```
  # h = {"a" => 100, "b" => 200, "c" => 300}
  # h.reject { |k, v| k > "a" } # => {"a" => 100}
  # h.reject { |k, v| v < 200 } # => {"b" => 200, "c" => 300}
  # ```
  def reject(& : K, V ->) : Hash(K, V)
    each_with_object({} of K => V) do |(k, v), memo|
      memo[k] = v unless yield k, v
    end
  end

  # Equivalent to `Hash#reject`, but makes modification on the current object rather than returning a new one. Returns `self`.
  def reject!(& : K, V -> _)
    each_entry_with_index do |entry, index|
      delete_entry_and_update_counts(index) if yield(entry.key, entry.value)
    end
    self
  end

  # Returns a new `Hash` without the given keys.
  #
  # ```
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.reject("a", "c") # => {"b" => 2, "d" => 4}
  # ```
  def reject(*keys) : Hash(K, V)
    hash = self.dup
    hash.reject!(*keys)
  end

  # Removes a list of keys out of hash.
  #
  # ```
  # hash = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}
  # hash.reject!(["a", "c"]) # => {"b" => 2, "d" => 4}
  # hash                     # => {"b" => 2, "d" => 4}
  # ```
  def reject!(keys : Enumerable) : self
    keys.each { |k| delete(k) }
    self
  end

  # Removes a list of keys out of hash.
  #
  # ```
  # hash = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}
  # hash.reject!("a", "c") # => {"b" => 2, "d" => 4}
  # hash                   # => {"b" => 2, "d" => 4}
  # ```
  def reject!(*keys) : self
    reject!(keys)
  end

  # Returns a new `Hash` with the given keys.
  #
  # ```
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select({"a", "c"})    # => {"a" => 1, "c" => 3}
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select("a", "c")      # => {"a" => 1, "c" => 3}
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select(["a", "c"])    # => {"a" => 1, "c" => 3}
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select(Set{"a", "c"}) # => {"a" => 1, "c" => 3}
  # ```
  def select(keys : Enumerable) : Hash(K, V)
    keys.each_with_object({} of K => V) do |k, memo|
      entry = find_entry(k)
      memo[k] = entry.value if entry
    end
  end

  # :ditto:
  def select(*keys) : Hash(K, V)
    self.select(keys)
  end

  # Removes every element except the given ones.
  #
  # ```
  # h1 = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select!({"a", "c"})
  # h2 = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select!("a", "c")
  # h3 = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select!(["a", "c"])
  # h4 = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select!(Set{"a", "c"})
  # h1 == h2 == h3 == h4 # => true
  # h1                   # => {"a" => 1, "c" => 3}
  # ```
  def select!(keys : Indexable) : self
    each_key { |k| delete(k) unless k.in?(keys) }
    self
  end

  # :ditto:
  def select!(keys : Enumerable) : self
    # Convert enumerable to a set to prevent exhaustion of elements
    key_set = keys.to_set
    each_key { |k| delete(k) unless k.in?(key_set) }
    self
  end

  # :ditto:
  def select!(*keys) : self
    select!(keys)
  end

  # Returns new `Hash` without `nil` values.
  #
  # ```
  # hash = {"hello" => "world", "foo" => nil}
  # hash.compact # => {"hello" => "world"}
  # ```
  def compact
    each_with_object({} of K => typeof(self.first_value.not_nil!)) do |(key, value), memo|
      memo[key] = value unless value.nil?
    end
  end

  # Removes all `nil` value from `self`. Returns `self`.
  #
  # ```
  # hash = {"hello" => "world", "foo" => nil}
  # hash.compact! # => {"hello" => "world"}
  # ```
  def compact! : self
    reject! { |key, value| value.nil? }
  end

  # Returns a new hash with all keys converted using the block operation.
  # The block can change a type of keys.
  # The block yields the key and value.
  #
  # ```
  # hash = {:a => 1, :b => 2, :c => 3}
  # hash.transform_keys { |key| key.to_s }                # => {"a" => 1, "b" => 2, "c" => 3}
  # hash.transform_keys { |key, value| key.to_s * value } # => {"a" => 1, "bb" => 2, "ccc" => 3}
  # ```
  def transform_keys(& : K, V -> K2) : Hash(K2, V) forall K2
    each_with_object({} of K2 => V) do |(key, value), memo|
      memo[yield(key, value)] = value
    end
  end

  # Returns a new hash with the results of running block once for every value.
  # The block can change a type of values.
  # The block yields the value and key.
  #
  # ```
  # hash = {:a => 1, :b => 2, :c => 3}
  # hash.transform_values { |value| value + 1 }             # => {:a => 2, :b => 3, :c => 4}
  # hash.transform_values { |value, key| "#{key}#{value}" } # => {:a => "a1", :b => "b2", :c => "c3"}
  # ```
  def transform_values(& : V, K -> V2) : Hash(K, V2) forall V2
    each_with_object({} of K => V2) do |(key, value), memo|
      memo[key] = yield(value, key)
    end
  end

  # Destructively transforms all values using a block. Same as transform_values but modifies in place.
  # The block cannot change a type of values.
  # The block yields the value and key.
  #
  # ```
  # hash = {:a => 1, :b => 2, :c => 3}
  # hash.transform_values! { |value| value + 1 }
  # hash # => {:a => 2, :b => 3, :c => 4}
  # hash.transform_values! { |value, key| value + key.to_s[0].ord }
  # hash # => {:a => 99, :b => 101, :c => 103}
  # ```
  # See `#update` for updating a *single* value.
  def transform_values!(& : V, K -> V) : self
    each_entry_with_index do |entry, i|
      new_value = yield entry.value, entry.key
      set_entry(i, Entry(K, V).new(entry.hash, entry.key, new_value))
    end
    self
  end

  # Zips two arrays into a `Hash`, taking keys from *ary1* and values from *ary2*.
  #
  # ```
  # Hash.zip(["key1", "key2", "key3"], ["value1", "value2", "value3"])
  # # => {"key1" => "value1", "key2" => "value2", "key3" => "value3"}
  # ```
  def self.zip(ary1 : Array(K), ary2 : Array(V))
    hash = {} of K => V
    ary1.each_with_index do |key, i|
      hash[key] = ary2[i]
    end
    hash
  end

  # Returns the first key in the hash.
  def first_key : K
    entry = first_entry?
    entry ? entry.key : raise "Can't get first key of empty Hash"
  end

  # Returns the first key if it exists, or returns `nil`.
  #
  # ```
  # hash = {"foo1" => "bar1", "foz2" => "baz2"}
  # hash.first_key? # => "foo1"
  # hash.clear
  # hash.first_key? # => nil
  # ```
  def first_key? : K?
    first_entry?.try &.key
  end

  # Returns the first value in the hash.
  def first_value : V
    entry = first_entry?
    entry ? entry.value : raise "Can't get first value of empty Hash"
  end

  # Returns the first value if it exists, or returns `nil`.
  #
  # ```
  # hash = {"foo1" => "bar1", "foz2" => "baz2"}
  # hash.first_value? # => "bar1"
  # hash.clear
  # hash.first_value? # => nil
  # ```
  def first_value? : V?
    first_entry?.try &.value
  end

  # Returns the last key in the hash.
  def last_key : K
    entry = last_entry?
    entry ? entry.key : raise "Can't get last key of empty Hash"
  end

  # Returns the last key if it exists, or returns `nil`.
  #
  # ```
  # hash = {"foo1" => "bar1", "foz2" => "baz2"}
  # hash.last_key? # => "foz2"
  # hash.clear
  # hash.last_key? # => nil
  # ```
  def last_key? : K?
    last_entry?.try &.key
  end

  # Returns the last value in the hash.
  def last_value : V
    entry = last_entry?
    entry ? entry.value : raise "Can't get last value of empty Hash"
  end

  # Returns the last value if it exists, or returns `nil`.
  #
  # ```
  # hash = {"foo1" => "bar1", "foz2" => "baz2"}
  # hash.last_value? # => "baz2"
  # hash.clear
  # hash.last_value? # => nil
  # ```
  def last_value? : V?
    last_entry?.try &.value
  end

  # Deletes and returns the first key-value pair in the hash,
  # or raises `IndexError` if the hash is empty.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.shift # => {"foo", "bar"}
  # hash       # => {"baz" => "qux"}
  #
  # hash = {} of String => String
  # hash.shift # raises IndexError
  # ```
  def shift : {K, V}
    shift { raise IndexError.new }
  end

  # Same as `#shift`, but returns `nil` if the hash is empty.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.shift? # => {"foo", "bar"}
  # hash        # => {"baz" => "qux"}
  #
  # hash = {} of String => String
  # hash.shift? # => nil
  # ```
  def shift? : {K, V}?
    shift { nil }
  end

  # Deletes and returns the first key-value pair in the hash.
  # Yields to the given block if the hash is empty.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.shift { true } # => {"foo", "bar"}
  # hash                # => {"baz" => "qux"}
  #
  # hash = {} of String => String
  # hash.shift { true } # => true
  # hash                # => {}
  # ```
  def shift(&)
    first_entry = first_entry?
    if first_entry
      delete_entry_and_update_counts(@first)
      {first_entry.key, first_entry.value}
    else
      yield
    end
  end

  # Empties a `Hash` and returns it.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.clear # => {}
  # ```
  def clear : self
    clear_impl
    self
  end

  # Compares with *other*. Returns `true` if all key-value pairs are the same.
  def ==(other : Hash) : Bool
    return false unless size == other.size
    each do |key, value|
      entry = other.find_entry(key)
      return false unless entry && entry.value == value
    end
    true
  end

  # Returns `true` if `self` is a subset of *other*.
  def proper_subset_of?(other : Hash) : Bool
    return false if other.size <= size
    all? do |key, value|
      other_value = other.fetch(key) { return false }
      other_value == value
    end
  end

  # Returns `true` if `self` is a subset of *other* or equals to *other*.
  def subset_of?(other : Hash) : Bool
    return false if other.size < size
    all? do |key, value|
      other_value = other.fetch(key) { return false }
      other_value == value
    end
  end

  # Returns `true` if *other* is a subset of `self`.
  def superset_of?(other : Hash) : Bool
    other.subset_of?(self)
  end

  # Returns `true` if *other* is a subset of `self` or equals to `self`.
  def proper_superset_of?(other : Hash) : Bool
    other.proper_subset_of?(self)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    # The hash value must be the same regardless of the
    # order of the keys.
    result = hasher.result

    each do |key, value|
      copy = hasher
      copy = key.hash(copy)
      copy = value.hash(copy)
      result &+= copy.result
    end

    result.hash(hasher)
  end

  # Duplicates a `Hash`.
  #
  # ```
  # hash_a = {"foo" => "bar"}
  # hash_b = hash_a.dup
  # hash_b.merge!({"baz" => "qux"})
  # hash_a # => {"foo" => "bar"}
  # ```
  def dup : Hash(K, V)
    hash = Hash(K, V).new
    hash.initialize_dup(self)
    hash
  end

  # Similar to `#dup`, but duplicates the values as well.
  #
  # ```
  # hash_a = {"foobar" => {"foo" => "bar"}}
  # hash_b = hash_a.clone
  # hash_b["foobar"]["foo"] = "baz"
  # hash_a # => {"foobar" => {"foo" => "bar"}}
  # ```
  def clone : Hash(K, V)
    {% if V == ::Bool || V == ::Char || V == ::String || V == ::Symbol || V < ::Number::Primitive %}
      clone = Hash(K, V).new
      clone.initialize_clone(self)
      clone
    {% else %}
      exec_recursive_clone do |hash|
        clone = Hash(K, V).new
        hash[object_id] = clone.object_id
        clone.initialize_clone(self)
        clone
      end
    {% end %}
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  # Converts to a `String`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.to_s       # => "{\"foo\" => \"bar\"}"
  # h.to_s.class # => String
  # ```
  def to_s(io : IO) : Nil
    executed = exec_recursive(:to_s) do
      io << '{'
      found_one = false
      each do |key, value|
        io << ", " if found_one
        key.inspect(io)
        io << " => "
        value.inspect(io)
        found_one = true
      end
      io << '}'
    end
    io << "{...}" unless executed
  end

  def pretty_print(pp) : Nil
    executed = exec_recursive(:pretty_print) do
      pp.list("{", self, "}") do |key, value|
        pp.group do
          key.pretty_print(pp)
          pp.text " =>"
          pp.nest do
            pp.breakable
            value.pretty_print(pp)
          end
        end
      end
    end
    pp.text "{...}" unless executed
  end

  # Returns an array of tuples with key and values belonging to this Hash.
  #
  # ```
  # h = {1 => 'a', 2 => 'b', 3 => 'c'}
  # h.to_a # => [{1, 'a'}, {2, 'b'}, {3, 'c'}]
  # ```
  # The order of the array follows the order the keys were inserted in the Hash.
  def to_a : Array({K, V})
    to_a_impl do |entry|
      {entry.key, entry.value}
    end
  end

  private def to_a_impl(& : Entry(K, V) -> U) forall U
    index = @first
    if @first == @deleted_count
      # If the deleted count equals the first element offset it
      # means that the only deleted elements are in (0...@first)
      # and so all the next ones are non-deleted.
      Array(U).new(size) do |i|
        value = yield get_entry(index)
        index += 1
        value
      end
    else
      Array(U).new(size) do |i|
        entry = get_entry(index)
        while entry.deleted?
          index += 1
          entry = get_entry(index)
        end
        index += 1
        yield entry
      end
    end
  end

  # Returns `self`.
  def to_h : self
    self
  end

  # Rebuilds the hash table based on the current keys.
  #
  # When using mutable data types as keys, modifying a key after it was inserted
  # into the `Hash` may lead to undefined behaviour. This method re-indexes the
  # hash using the current keys.
  def rehash : Nil
    do_compaction(rehash: true)
  end

  # Inverts keys and values. If there are duplicated values, the last key becomes the new value.
  #
  # ```
  # {"foo" => "bar"}.invert                 # => {"bar" => "foo"}
  # {"foo" => "bar", "baz" => "bar"}.invert # => {"bar" => "baz"}
  # ```
  def invert : Hash(V, K)
    hash = Hash(V, K).new(initial_capacity: @size)
    self.each do |k, v|
      hash[v] = k
    end
    hash
  end

  struct Entry(K, V)
    getter key, value, hash

    def initialize(@hash : UInt32, @key : K, @value : V)
    end

    def self.deleted
      key = uninitialized K
      value = uninitialized V
      new(0_u32, key, value)
    end

    def deleted? : Bool
      @hash == 0_u32
    end

    def clone
      Entry(K, V).new(hash, key, value.clone)
    end
  end

  private module BaseIterator
    def initialize(@hash)
      @index = @hash.@first
    end

    def base_next(&)
      while true
        if @index < @hash.entries_size
          entry = @hash.entries[@index]
          if entry.deleted?
            @index += 1
          else
            value = yield entry
            @index += 1
            return value
          end
        else
          return stop
        end
      end
    end
  end

  private class EntryIterator(K, V)
    include BaseIterator
    include Iterator({K, V})

    @hash : Hash(K, V)
    @index : Int32

    def next
      base_next { |entry| {entry.key, entry.value} }
    end
  end

  private class KeyIterator(K, V)
    include BaseIterator
    include Iterator(K)

    @hash : Hash(K, V)
    @index : Int32

    def next
      base_next &.key
    end
  end

  private class ValueIterator(K, V)
    include BaseIterator
    include Iterator(V)

    @hash : Hash(K, V)
    @index : Int32

    def next
      base_next &.value
    end
  end
end
