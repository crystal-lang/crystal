{% if flag?(:win32) && flag?(:gnu) %}
  require "c/fibersapi"
{% end %}

# :nodoc:
class Thread
  # :nodoc:
  module LocalStorage
    alias Destructor = Proc(Void*, Nil)

    def self.get(key : Key, &) : Void*
      get(key) || set(key, yield.as(Void*))
    end

    {% if flag?(:android) || flag?(:openbsd) %}
      alias Key = LibC::PthreadKeyT

      def self.create(destructor : Destructor? = nil) : Key
        err = LibC.pthread_key_create(out key, destructor)
        raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
        key
      end

      def self.get(key : Key) : Void*
        LibC.pthread_getspecific(key)
      end

      def self.set(key : Key, value : Void*) : Void*
        err = LibC.pthread_setspecific(key, value)
        raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
        value
      end

      def self.call_destructors : Nil
      end
    {% elsif flag?(:win32) && flag?(:gnu) %}
      alias Key = LibC::DWORD

      def self.create(destructor : Destructor? = nil) : Key
        key = LibC.FlsAlloc(nil)
        raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if key == LibC::FLS_OUT_OF_INDEXES
        key
      end

      def self.get(key : Key) : Void*
        LibC.FlsGetValue(key)
      end

      def self.set(key : Key, value : Void*) : Void*
        ret = LibC.FlsSetValue(key, value)
        raise RuntimeError.from_winerror("FlsSetValue") if ret == 0
        value
      end

      def self.call_destructors : Nil
      end
    {% else %}
      # The key is free to (re)allocate.
      FREE = Destructor.new(Pointer(Void).null, Pointer(Void).null)

      # The key is allocated without a destructor.
      INVALID = Destructor.new(Pointer(Void).new(-1.to_u64!), Pointer(Void).new(-1.to_u64!))

      # The maximum number of keys.
      MAX_KEYS = 128_u32

      # Unsigned so we don't have to deal with negative indexes.
      alias Key = UInt32

      @@destructors = Pointer(Destructor).null
      @@mutex = Thread::Mutex.new
      @@size = 0_u32

      @[ThreadLocal]
      @@local_table = uninitialized Table*

      def self.create(destructor : Destructor? = nil) : Key
        @@mutex.synchronize do
          # scan for a free key
          key = 0_u32
          max = @@size

          while key < max
            break if @@destructors[key] == FREE
            key &+= 1_u32
          end

          if key == max
            # full: grow
            new_size = Math.pw2ceil((max + 1_u32).clamp(4_u32..))
            raise RuntimeError.new("Too many thread local keys") if new_size > MAX_KEYS

            bytesize = sizeof(Destructor) * new_size
            @@destructors = GC.realloc(@@destructors.as(Void*), bytesize).as(Destructor*)
            @@size = new_size
          end

          # allocate
          @@destructors[key] = destructor || INVALID

          key
        end
      end

      def self.delete(key : Key) : Void*
        @@mutex.synchronize do
          raise RuntimeError.new("Invalid key") if key >= @@size || @@destructors[key] == FREE
          @@destructors[key] = FREE
        end
      end

      def self.get(key : Key) : Void*
        if (local = @@local_table) && (key < local.value.size)
          local.value.to_unsafe[key]
        else
          Pointer(Void).null
        end
      end

      def self.set(key : Key, value : Void*) : Void*
        local = @@local_table

        if local.null? || (key >= local.value.size)
          max = @@size
          raise RuntimeError.new("Invalid key") unless key < max

          # no thread local table or too small: allocate/grow
          bytesize = sizeof(Table) + sizeof(Void*) * max
          local = GC.realloc(local.as(Void*), bytesize).as(Table*)
          local.value.size = max

          # the GC can't access the local storage, so we must keep a pointer on
          # Thread.current that must be reachable for the whole time the thread
          # a alive
          Thread.current.local_storage = local
          @@local_table = local
        end

        local.value.to_unsafe[key] = value
      end

      def self.call_destructors : Nil
        return if @@destructors.null?
        return if (local = @@local_table).null?

        @@mutex.synchronize do
          @@size.times do |key|
            destructor = @@destructors[key]
            next if destructor == FREE || destructor == INVALID
            next if key >= local.value.size
            next if (value = local.value.to_unsafe[key]).null?

            local.value.to_unsafe[key] = Pointer(Void).null
            destructor.call(value) rescue nil
          end
        end
      end

      @[Extern]
      struct Table
        property size : UInt32
        @table : StaticArray(Void*, 0)

        # never called
        private def initialize
          @size = 0_u32
          @table = uninitialized StaticArray(Void*, 0)
        end

        def to_unsafe : Void**
          @table.to_unsafe
        end
      end
    {% end %}
  end
end
