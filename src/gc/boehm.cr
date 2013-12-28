require "thread"

lib LibGC("gc")
  fun init = GC_init
  fun malloc = GC_malloc(size : UInt32) : Void*
  fun malloc_atomic = GC_malloc_atomic(size : UInt32) : Void*
  fun realloc = GC_realloc(ptr : Void*, size : UInt32) : Void*
  fun free = GC_free(ptr : Void*)
  fun collect_a_little = GC_collect_a_little : Int32
  fun collect = GC_gcollect
  fun add_roots = GC_add_roots(low : Void*, high : Void*)
  fun enable = GC_enable
  fun disable = GC_disable

  fun pthread_create = GC_pthread_create(thread : PThread::Thread*, attr : Void*, start : Void* ->, arg : Void*)
  fun pthread_join = GC_pthread_join(thread : PThread::Thread, value : Void**) : Int32
end

fun __crystal_malloc(size : UInt32) : Void*
  LibGC.malloc(size)
end

fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  LibGC.realloc(ptr, size)
end

module GC
  def self.init
    LibGC.init
  end

  def self.collect
    LibGC.collect
  end

  def self.enable
    LibGC.enable
  end

  def self.disable
    LibGC.disable
  end

  def self.free(pointer : Void*)
    LibGC.free(pointer)
  end
end

# Rewrite Thread creation and join using LibGC routines
class Thread(T, R)
  def initialize(arg : T, func)
    @func = func
    @arg = arg
    LibGC.pthread_create(out @th, nil, ->start(Void*), nil)
  end

  def join
    LibGC.pthread_join(@th, out ret)
    (ret as R*).value
  end
end


