# A Proc represents a function pointer with an optional context (the closure data). It is typically created with a proc literal:
#
# ```
# # A proc without arguments
# ->{ 1 } # Proc(Int32)
#
# # A proc with one argument
# ->(x : Int32) { x.to_s } # Proc(Int32, String)
#
# # A proc with two arguments:
# ->(x : Int32, y : Int32) { x + y } # Proc(Int32, Int32, Int32)
# ```
# The types of the arguments are mandatory, except when directly sending a proc literal to a lib fun in C bindings.
#
# The return type is inferred from the proc's body.
#
# A special new method is provided too:
#
# ```
# Proc(Int32, String).new { |x| x.to_s } # Proc(Int32, String)
# ```
#
# This form allows you to specify the return type and to check it against the proc's body.
#
# Another way to create a Proc is by capturing a block:
#
# ```
# def capture(&block : Int32 -> Int32)
#   # block argument is used, so block is turned into a Proc
#   block
# end
#
# proc = capture { |x| x + 1 } # Proc(Int32, Int32)
# proc.call(1)                 # => 2
# ```
#
# When capturing blocks, the type of the arguments and return type must be specified in the capturing
# method block signature.
#
# ### Passing a Proc to a C function
#
# Passing a Proc to a C function, for example as a callback, is possible as long as the Proc isn't a closure. If it is, either
# a compile-time or runtime error will happen depending on whether the compiler can check this. The reason
# is that a Proc is internally represented as two void pointers, one having the function
# pointer and another the closure data. If just the function pointer is passed, the closure data will be missing
# at invocation time.
#
# Most of the time a C function that allows setting a callback also provide an argument for custom data. This custom data
# is then sent as an argument to the callback. For example, suppose a C function that invokes a callback at every tick,
# passing that tick:
#
# ```
# lib LibTicker
#   fun on_tick(callback : (Int32, Void* ->), data : Void*)
# end
# ```
#
# To properly define a wrapper for this function we must send the Proc as the callback data, and then
# convert that callback data to the Proc and finally invoke it.
#
# ```
# module Ticker
#   # The callback for the user doesn't have a Void*
#   def self.on_tick(&callback : Int32 ->)
#     # We must save this in Crystal-land so the GC doesn't collect it (*)
#     @@callback = callback
#
#     # Since Proc is a {Void*, Void*}, we can't turn that into a Void*, so we
#     # "box" it: we allocate memory and store the Proc there
#     boxed_data = Box.box(callback)
#
#     # We pass a callback that doesn't form a closure, and pass the boxed_data as
#     # the callback data
#     LibTicker.on_tick(->(tick, data) {
#       # Now we turn data back into the Proc, using Box.unbox
#       data_as_callback = Box(typeof(callback)).unbox(data)
#       # And finally invoke the user's callback
#       data_as_callback.call(tick)
#     }, boxed_data)
#   end
# end
#
# Ticker.on_tick do |tick|
#   puts tick
# end
# ```
#
# Note that we save the callback in `@@callback`. The reason is that if we don't do it, and our code doesn't
# reference it anymore, the GC will collect it. The C library will of course store the callback, but Crystal's
# GC has no way of knowing that.
struct Proc
  def self.new(pointer : Void*, closure_data : Void*)
    func = {pointer, closure_data}
    ptr = pointerof(func) as self*
    ptr.value
  end

  def pointer
    internal_representation[0]
  end

  def closure_data
    internal_representation[1]
  end

  def closure?
    !closure_data.null?
  end

  private def internal_representation
    func = self
    ptr = pointerof(func) as {Void*, Void*}*
    ptr.value
  end

  def ==(other : self)
    pointer == other.pointer && closure_data == other.closure_data
  end

  def ===(other : self)
    self == other
  end

  def ===(other)
    call(other)
  end

  def hash
    object_id.hash
  end

  def to_s(io)
    io << "#<"
    io << {{@type.name.stringify}}
    io << ":0x"
    pointer.address.to_s(16, io)
    if closure?
      io << ":closure"
    end
    io << ">"
    nil
  end
end
