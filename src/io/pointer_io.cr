struct PointerIO
  include IO

  def initialize(@pointer : UInt8**)
  end

  def write(slice : Slice(UInt8), count)
    slice.copy_to(@pointer.value, count)
    @pointer.value += count
  end
end
