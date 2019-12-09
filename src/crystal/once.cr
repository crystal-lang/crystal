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
  {% if flag?(:preview_mt) %}
    @mutex = Mutex.new(:reentrant)
  {% end %}

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

  {% if flag?(:preview_mt) %}
    def once(flag : Bool*, initializer : Void*)
      unless flag.value
        @mutex.synchronize do
          previous_def
        end
      end
    end
  {% end %}
end

fun __crystal_once_init : Void*
  Crystal::OnceState.new.as(Void*)
end

fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
  state.as(Crystal::OnceState).once(flag, initializer)
end
