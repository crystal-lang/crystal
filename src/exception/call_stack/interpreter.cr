require "../../crystal/system/print_error"

# :nodoc:
struct Exception::CallStack
  skip(__FILE__)

  @[Primitive(:interpreter_call_stack_unwind)]
  protected def self.unwind : Array(Void*)
  end

  def self.decode_address(ip)
    ip.unsafe_as(String).split("|", 4)
  end

  def self.decode_line_number(pc)
    _, line, column, file = pc
    {file, line, column}
  end

  def self.decode_function_name(pc)
    pc[0]
  end

  def self.decode_frame(pc)
    pc[0]
  end

  def self.print_backtrace : Nil
    unwind.each do |frame|
      Crystal::System.print_error frame.unsafe_as(String)
    end
  end
end
