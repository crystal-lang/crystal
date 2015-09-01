struct PointerIO
  include IO

  def initialize(@pointer : UInt8**)
  end

  def read(slice : Slice(UInt8))
    count = slice.length
    slice.copy_from(@pointer.value, count)
    @pointer.value += count
    count
  end

  def write(slice : Slice(UInt8))
    count = slice.length
    slice.copy_to(@pointer.value, count)
    @pointer.value += count
    count
  end
end
