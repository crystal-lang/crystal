struct PointerIO
  include IO

  def initialize(@pointer : UInt8**)
  end

  def write(buffer : UInt8*, count)
    @pointer.value.memcpy(buffer, count)
    @pointer.value += count
  end
end
