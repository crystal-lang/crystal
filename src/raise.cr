require "c/stdio"
require "c/stdlib"
require "crystal/system/exceptions"
require "crystal/system/panic"
require "exception/call_stack"

Exception::CallStack.skip(__FILE__)
Exception::CallStack.skip("#{__DIR__}/crystal/system/exceptions")
Exception::CallStack.skip("#{__DIR__}/crystal/system/win32/exceptions")
Exception::CallStack.skip("#{__DIR__}/crystal/system/wasi/exceptions")
Exception::CallStack.skip("#{__DIR__}/crystal/system/unix/exceptions")

{% unless flag?(:interpreted) || (flag?(:win32) && !flag?(:gnu)) || flag?(:wasm32) %}
  # :nodoc:
  @[Raises]
  fun __crystal_raise(unwind_ex : LibUnwind::Exception*) : NoReturn
    ret = LibUnwind.raise_exception(unwind_ex)
    Crystal::System.print_error "Failed to raise an exception: %s\n", ret.to_s
    Exception::CallStack.print_backtrace
    Crystal::System.print_exception("\nTried to raise:", unwind_ex.value.exception_object.as(Exception))
    LibC.exit(ret)
  end
{% end %}

# Raises the *exception*.
#
# This will set the exception's callstack if it hasn't been already.
# Re-raising a previously caught exception won't replace the callstack.
@[Raises]
def raise(exception : Exception) : NoReturn
  {% if flag?(:debug_raise) %}
    STDERR.puts
    STDERR.puts "Attempting to raise: "
    exception.inspect_with_backtrace(STDERR)
  {% end %}

  {% if flag?(:wasm32) && compare_versions(Crystal::LLVM_VERSION, "24.0.0") < 0 %}
    Crystal::System.print_error "EXITING: Attempting to raise:\n%s\n", exception.inspect_with_backtrace
    LibIntrinsics.debugtrap
    LibC.exit(1)
  {% else %}
    exception.callstack ||= Exception::CallStack.new
    raise_without_backtrace(exception)
  {% end %}
end

# Raises an `Exception` with the *message*.
@[Raises]
def raise(message : String) : NoReturn
  raise Exception.new(message)
end

# :nodoc:
fun __crystal_raise_string(message : UInt8*)
  raise String.new(message)
end

# :nodoc:
fun __crystal_raise_overflow : NoReturn
  raise OverflowError.new
end

# :nodoc:
fun __crystal_raise_closure_to_c : NoReturn
  raise "passing a closure to C is not allowed"
end

{% if flag?(:interpreted) %}
  # :nodoc:
  def __crystal_raise_cast_failed(obj, type_name : String, location : String)
    raise TypeCastError.new("Cast from #{obj.class} to #{type_name} failed, at #{location}")
  end
{% else %}
  # :nodoc:
  fun __crystal_raise_cast_failed(from_type : Void*, to_type : Void*, location : Void*) : NoReturn
    if location
      raise TypeCastError.new("Cast from #{from_type.as(String)} to #{to_type.as(String)} failed, at #{location.as(String)}")
    else
      raise TypeCastError.new("Cast from #{from_type.as(String)} to #{to_type.as(String)} failed")
    end
  end
{% end %}
