lib C
  fun malloc(size : Int32) : Void*
  fun realloc(pointer : Void*, size : Int32) : Void*
end

$gc_table_size = 1024
$gc_table_entry = 0
$gc_table = C.malloc($gc_table_size * 8).as(Pointer(Pointer(Void)))

fun __crystal_malloc(size : Int32) : Void*
  pointer = C.malloc(size + 1)

  $gc_table[$gc_table_entry] = pointer
  $gc_table_entry += 1

  if $gc_table_entry == $gc_table_size
    $gc_table_size += 1
    $gc_table = C.realloc($gc_table.as(Void), $gc_table_size * 8).as(Pointer(Pointer(Void)))
  end

  pointer + 1
end

fun __crystal_realloc(pointer : Void*, size : Int32) : Void*
  pointer = C.realloc(pointer - 1, size + 1)
  pointer + 1
end
