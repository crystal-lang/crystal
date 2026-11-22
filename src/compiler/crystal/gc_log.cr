module Crystal
  # Records every garbage collection so that `--stats` can report how much heap
  # memory each one freed and how long it took.
  #
  # Boehm GC calls the collection event hook with its allocation lock held, and
  # partly with the world stopped. The hook therefore neither allocates nor
  # takes the lock again: it reads the unsynchronized heap getters and stores
  # the numbers in a fixed buffer, which `.drain` empties later.
  #
  # The heap in use before a collection is the heap size minus its free
  # blocks, so it includes the garbage the collection is about to find. The
  # live size after it adds up the objects the collection marked, which is
  # exact: the heap in use would still count the garbage in partly used
  # blocks, because Boehm only sweeps those lazily while allocating. Adding up
  # the marked objects walks all of them, which lengthens each collection; the
  # reported duration excludes that walk.
  module GCLog
    record Collection,
      number : UInt64,
      used_before : UInt64,
      live_after : UInt64,
      duration : Time::Span

    # Collections recorded between two calls to `.drain`; later ones are only
    # counted.
    CAPACITY = 256

    {% unless flag?(:gc_none) %}
      @@installed = false
      @@previous_hook : LibGC::OnCollectionEventProc?

      @@collections = uninitialized StaticArray(Collection, CAPACITY)
      @@size = 0
      @@dropped = 0

      @@drained = uninitialized StaticArray(Collection, CAPACITY)
      @@drained_size = 0
      @@drained_dropped = 0

      @@started_at = Time.instant
      @@used_before = 0_u64
      @@live = 0_u64
    {% end %}

    # Starts recording collections. Calling it again has no effect.
    def self.install : Nil
      {% unless flag?(:gc_none) %}
        return if @@installed
        @@installed = true

        @@previous_hook = LibGC.get_on_collection_event
        LibGC.set_on_collection_event(->(event : LibGC::EventType) {
          GCLog.on_collection_event(event)
        })
      {% end %}
    end

    # Yields the collections recorded since the previous call, oldest first,
    # and returns how many more happened that did not fit in the buffer.
    def self.drain(& : Collection ->) : Int32
      {% if flag?(:gc_none) %}
        0
      {% else %}
        return 0 unless @@installed

        LibGC.call_with_alloc_lock(->(_data : Void*) {
          GCLog.take_collections
          Pointer(Void).null
        }, nil)

        @@drained_size.times { |index| yield @@drained[index] }
        @@drained_dropped
      {% end %}
    end

    {% unless flag?(:gc_none) %}
      # :nodoc:
      def self.on_collection_event(event : LibGC::EventType) : Nil
        case event
        when .start?
          @@used_before = used_heap
          @@started_at = Time.instant
        when .end?
          duration = @@started_at.elapsed
          record_collection Collection.new(
            number: LibGC.gc_no.to_u64!,
            used_before: @@used_before,
            live_after: live_heap,
            duration: duration)
        end

        @@previous_hook.try &.call(event)
      end

      # :nodoc:
      # Must be called with the allocation lock held.
      def self.take_collections : Nil
        @@drained = @@collections
        @@drained_size = @@size
        @@drained_dropped = @@dropped
        @@size = 0
        @@dropped = 0
      end

      private def self.record_collection(collection : Collection) : Nil
        if @@size < CAPACITY
          @@collections[@@size] = collection
          @@size += 1
        else
          @@dropped += 1
        end
      end

      # Adds up the objects the last collection marked. Must be called with
      # the allocation lock held, before the next collection clears the marks.
      private def self.live_heap : UInt64
        @@live = 0_u64
        LibGC.enumerate_reachable_objects_inner(->(_object : Void*, bytes : LibC::SizeT, _data : Void*) {
          GCLog.add_live(bytes)
        }, nil)
        @@live
      end

      # :nodoc:
      def self.add_live(bytes : LibC::SizeT) : Nil
        @@live &+= bytes.to_u64!
      end

      private def self.used_heap : UInt64
        LibGC.get_heap_size.to_u64! &- LibGC.get_free_bytes.to_u64!
      end
    {% end %}
  end
end
