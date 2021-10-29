{% skip_file if flag?(:win32) %}

require "./call_stack/libunwind"

# Returns the current execution stack as an array containing strings
# usually in the form file:line:column or file:line:column in 'method'.
def caller : Array(String)
  Exception::CallStack.new.printable_backtrace
end

# :nodoc:
struct Exception::CallStack
  # Compute current directory at the beginning so filenames
  # are always shown relative to the *starting* working directory.
  CURRENT_DIR = begin
    if dir = Process::INITIAL_PWD
      dir += File::SEPARATOR unless dir.ends_with?(File::SEPARATOR)
      dir
    end
  end

  @@skip = [] of String

  def self.skip(filename) : Nil
    @@skip << filename
  end

  skip(__FILE__)

  @callstack : Array(Void*)
  @backtrace : Array(String)?

  def initialize
    @callstack = CallStack.unwind
  end

  def printable_backtrace : Array(String)
    @backtrace ||= decode_backtrace
  end
end
