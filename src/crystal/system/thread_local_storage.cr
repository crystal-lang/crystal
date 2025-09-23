{% if flag?(:win32) && flag?(:gnu) %}
  require "c/fibersapi"
{% end %}

# :nodoc:
class Thread
  # :nodoc:
  #
  # The GC can't access the local storage, so we must keep a pointer to the
  # table on the Thread instance that is reachable for as long as the thread is
  # alive.
  #
  # We could spare this pointer if the table was uncollectible: the GC allocates
  # the memory, always scans it (even without explicit references) and never
  # collects it until it's explicitly told to be freed.
  protected property local_storage = Pointer(LocalStorage::Table).null

  # :nodoc:
  module LocalStorage
    # FIXME: we should be able to use @[ThreadLocal] on every target: the
    # compiler needs to set the llvm::TargetOptions::EmulatedLTS option for
    # Android < 29, MinGW and OpenBSD, though mostly for overall consistency
    # since it might be set by default for some targets already.

    {% if flag?(:android) || flag?(:openbsd) %}
      @@key = uninitialized LibC::PthreadKeyT
      err = LibC.pthread_key_create(pointerof(@@key), nil)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0

      private def self.local_table : Table*
        LibC.pthread_getspecific(@@key).as(Table*)
      end

      private def self.local_table=(local_table : Table*)
        err = LibC.pthread_setspecific(@@key, local_table)
        raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
        local_table
      end
    {% elsif flag?(:win32) && flag?(:gnu) %}
      @@key = uninitialized LibC::DWORD
      @@key = LibC.FlsAlloc(nil)
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if @@key == LibC::FLS_OUT_OF_INDEXES

      private def self.local_table : Table*
        LibC.FlsGetValue(@@key).as(Table*)
      end

      private def self.local_table=(local_table : Table*)
        ret = LibC.FlsSetValue(@@key, local_table.as(Void*))
        raise RuntimeError.from_winerror("FlsSetValue") if ret == 0
        local_table
      end
    {% else %}
      @[ThreadLocal]
      @@local_table = uninitialized Table*

      private def self.local_table : Table*
        @@local_table
      end

      private def self.local_table=(@@local_table : Table*)
      end
    {% end %}

    alias Destructor = Proc(Void*, Nil)

    # The key is free to (re)allocate (zero memory).
    FREE = Destructor.new(Pointer(Void).null, Pointer(Void).null)

    # The key is allocated without a destructor (invalid proc).
    INVALID = Destructor.new(Pointer(Void).new(-1.to_u64!), Pointer(Void).new(-1.to_u64!))

    # The maximum number of keys.
    MAX_KEYS = 128_u32

    struct Key
      # Unsigned so we don't have to deal with negative indexes.
      getter value : UInt32

      def initialize(@value)
      end
    end

    @@destructors = Pointer(Destructor).null
    @@mutex = Thread::Mutex.new
    @@size = 0_u32

    # Declares a new thread local value with an optional *destructor*. Returns
    # the key to access the value. Each thread will have a distinct value.
    @[NoInline]
    def self.create(destructor : Destructor? = nil) : Key
      @@mutex.synchronize do
        # scan for a free key
        i = 0_u32
        max = @@size

        while i < max
          break if @@destructors[i] == FREE
          i &+= 1_u32
        end

        if i == max
          # full: grow
          new_size = Math.pw2ceil((max + 1_u32).clamp(4_u32..))
          raise RuntimeError.new("Too many thread local keys") if new_size > MAX_KEYS

          bytesize = sizeof(Destructor) * new_size
          @@destructors = GC.realloc(@@destructors.as(Void*), bytesize).as(Destructor*)
          @@size = new_size
        end

        # register the key
        @@destructors[i] = destructor || INVALID

        Key.new(i)
      end
    end

    # Deletes a previously declared key. This doesn't call the destructor for
    # any thread local value: the caller is responsible to cleanup all the
    # values for all the threads before deleting a key.
    @[NoInline]
    def self.delete(key : Key) : Void*
      @@mutex.synchronize do
        raise RuntimeError.new("Invalid key") if key.value >= @@size || @@destructors[key.value] == FREE
        @@destructors[key.value] = FREE
      end
    end

    # Simple wrapper around `#get` and `#set` where *constructor* must return a
    # new value for when the current thread doesn't have a value for *key* yet.
    def self.get(key : Key, &constructor : -> Void*) : Void*
      get(key) || set(key, yield.as(Void*))
    end

    # Returns the value for the previously declared *key* for the current
    # thread. Returns a NULL pointer if the value hasn't been set for the
    # current thread.
    @[AlwaysInline]
    def self.get(key : Key) : Void*
      if (table = local_table) && (key.value < table.value.size)
        table.value.to_unsafe[key.value]
      else
        Pointer(Void).null
      end
    end

    # Replaces the value for the previously declared *key* for the current
    # thread. Doesn't call the destructor even if the value already exists: the
    # caller is expected to do the cleanup.
    @[NoInline]
    def self.set(key : Key, value : Void*) : Void*
      table = local_table

      if table.null? || (key.value >= table.value.size)
        max = @@size
        raise RuntimeError.new("Invalid key") unless key.value < max

        # no thread local table or too small: allocate/grow
        bytesize = sizeof(Table) + sizeof(Void*) * max
        table = GC.realloc(table.as(Void*), bytesize).as(Table*)
        table.value.size = max

        Thread.current.local_storage = table
        self.local_table = table
      end

      table.value.to_unsafe[key.value] = value
    end

    # Executes the destructors for all the values in the current thread's local
    # storage that aren't NULL if their key has an associated destructor.
    #
    # Each destructor is called once to avoid infinite loops. If a destructor
    # causes a value to be created again, the destructor won't be called again,
    # possibly leaking the value!
    def self.call_destructors : Nil
      return if @@destructors.null?
      return if (table = local_table).null?

      @@mutex.synchronize do
        @@size.times do |i|
          destructor = @@destructors[i]
          next if destructor == FREE || destructor == INVALID
          next if i >= table.value.size
          next if (value = table.value.to_unsafe[i]).null?

          table.value.to_unsafe[i] = Pointer(Void).null
          destructor.call(value) rescue nil
        end
      end
    end

    # :nodoc:
    @[Extern]
    struct Table
      property size : UInt32
      @table : StaticArray(Void*, 0)

      private def initialize
        @size = 0_u32
        @table = uninitialized StaticArray(Void*, 0)
      end

      def to_unsafe : Void**
        @table.to_unsafe
      end
    end
  end
end
