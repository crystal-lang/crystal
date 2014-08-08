struct PointerIO
  include IO

  def initialize(@pointer : UInt8**)
  end

  def write(buffer : Slice(UInt8), count)
    @pointer.value.copy_from(buffer.pointer, count)
    @pointer.value += count
  end
end
