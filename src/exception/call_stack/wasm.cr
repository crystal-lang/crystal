struct Exception::CallStack
  skip(__FILE__)

  # Must match CodeGenVisitor's shadow_stack_frame_type and static metadata.
  # Only metadata pointers may escape an unwind: frames are stack allocations.
  private struct ShadowFrame
    getter previous : ShadowFrame*
    getter metadata : Void*

    def initialize(@previous : ShadowFrame*, @metadata : Void*)
    end
  end

  private struct ShadowMetadata
    getter function : String
    getter file : String
    getter line : Int32
    getter column : Int32

    def initialize(@function : String, @file : String, @line : Int32, @column : Int32)
    end
  end

  @[Primitive(:shadow_stack_head)]
  private def self.shadow_stack_head : Void*
  end

  def self.load_debug_info_impl : Nil
  end

  def self.decode_address(ip)
    ip
  end

  def self.decode_line_number(pc)
    metadata = pc.as(ShadowMetadata*)
    {metadata.value.file, metadata.value.line, metadata.value.column}
  end

  def self.decode_function_name(pc)
    pc.as(ShadowMetadata*).value.function
  end

  protected def self.decode_frame(pc)
  end

  protected def self.unwind : Array(Void*)
    # Capture before allocating, so allocation's own frames are never included.
    frame = shadow_stack_head.as(ShadowFrame*)
    result = [] of Void*
    until frame.null?
      result << frame.value.metadata
      frame = frame.value.previous
    end
    result
  end

  def self.print_backtrace : Nil
    frame = shadow_stack_head.as(ShadowFrame*)
    until frame.null?
      pc = frame.value.metadata
      print_frame_location(pc.as(ShadowMetadata*))
      frame = frame.value.previous
    end
  end

  private def self.print_frame_location(metadata)
    Crystal::System.print_error "%s at %s:%d:%d\n",
      metadata.value.function,
      metadata.value.file,
      metadata.value.line,
      metadata.value.column
  end
end
