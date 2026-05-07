module Crystal::System
  struct MemoryMap
    @pointer : UInt8*
    getter size : LibC::SizeT
    getter? read_only : Bool

    # def unmap : Nil | Errno | WinError

    def to_slice : Bytes
      Bytes.new(@pointer, @size.to_i32, read_only: @read_only)
    end

    def to_slice(offset : Int, count : Int) : Bytes
      Bytes.new(@pointer + offset, (@size - count).to_i32, read_only: @read_only)
    end

    def to_unsafe : UInt8*
      @pointer
    end
  end

  # def self.memory_map(handle : FileDescriptor::Handle, offset : Int, size : Int, read_only = true) : MemoryMap | Errno | WinError
end

{% if flag?(:unix) %}
  require "./unix/memory_map"
{% elsif flag?(:win32) %}
  require "./win32/memory_map"
{% else %}
  {% raise "No Crystal::System::MemoryMap implementation available" %}
{% end %}
