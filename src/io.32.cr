lib C
  fun fseeko = fseeko64(file : File, offset : Int64, whence : Int32) : Int32
  fun ftello = ftello64(file : File) : Int64
end
