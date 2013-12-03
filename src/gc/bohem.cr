lib LibGC("gc")
  fun init = GC_init
  fun malloc = GC_malloc(size : UInt32) : Void*
  fun realloc = GC_realloc(ptr : Void*, size : UInt32) : Void*
  fun collect_a_little = GC_collect_a_little : Int32
  fun collect = GC_gcollect
  fun add_roots = GC_add_roots(low : Void*, high : Void*)
  fun enable = GC_enable
  fun disable = GC_disable
end

LibGC.init

fun __crystal_malloc(size : UInt32) : Void*
  LibGC.malloc(size)
end

fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  LibGC.realloc(ptr, size)
end

