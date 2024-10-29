# This file defines the functions `__crystal_once_init` and `__crystal_once` expected
# by the compiler. `__crystal_once` is called each time a constant or class variable
# has to be initialized and is its responsibility to verify the initializer is executed
# only once. `__crystal_once_init` is executed only once at the beginning of the program
# and the result is passed on each call to `__crystal_once`.

# This implementation uses an array to store the initialization flag pointers for each value
# to find infinite loops and raise an error. In multithread mode a mutex is used to
# avoid race conditions between threads.

# :nodoc:
class Crystal::OnceState
  @rec = [] of Bool*

  def once(flag : Bool*, initializer : Void*)
    unless flag.value
      if @rec.includes?(flag)
        raise "Recursion while initializing class variables and/or constants"
      end
      @rec << flag

      Proc(Nil).new(initializer, Pointer(Void).null).call
      flag.value = true

      @rec.pop
    end
  end

  # on Win32, `Crystal::System::FileDescriptor#@@reader_thread` spawns a new
  # thread even without the `preview_mt` flag, and the thread can also reference
  # Crystal constants, leading to race conditions, so we always enable the mutex
  # TODO: can this be improved?
  {% if flag?(:preview_mt) || flag?(:win32) %}
    @mutex = Mutex.new(:reentrant)

    def once(flag : Bool*, initializer : Void*)
      unless flag.value
        @mutex.synchronize do
          previous_def
        end
      end
    end
  {% end %}
end

# :nodoc:
fun __crystal_once_init : Void*
  Crystal::OnceState.new.as(Void*)
end

# :nodoc:
fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
  state.as(Crystal::OnceState).once(flag, initializer)
end
