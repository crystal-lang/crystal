lib LibIntrinsics
  fun f16tof32 = "llvm.convert.from.fp16.f32"(Int16) : Float32
  fun f16tof64 = "llvm.convert.from.fp16.f64"(Int16) : Float64

  fun f32tof16 = "llvm.convert.to.fp16.f32"(Float32) : Int16
  fun f64tof16 = "llvm.convert.to.fp16.f64"(Float64) : Int16
end

@[Extern]
# A [half-precision floating-point number](https://en.wikipedia.org/wiki/Half-precision_floating-point_format).
#
# The operations provided by `Float16` are minimal:
# - Create a Float16 from either Float32 or Float64: `new(Float32)`, `new(Float64)`
# - Convert a Float16 to either Float32 or Float64: `#to_f32`, `#to_f64`, `#to_f`
# - Equality: `#==`
#
# The reason is that the typical way to work with Float16 is:
# 1. An external C API returns Float16, you read a Float16 from it
# 2. You immediately convert it to Float32 or Float64
# 3. You work with Float32 and Float64, doing any necessary math
# 4. You convert the result to Float16 and send it back to the external API
#
# The `Float16` is marked with the `@[Extern]` annotation so it can
# be used in C bindings:
#
# ```
# lib LibSome
#   fun get_a_float16 : Float16
#   fun set_a_float16(value : Float16)
# end
#
# # Read from an external API
# float16 = LibSome.get_a_float16
#
# # Immediately convert to Float64
# float64 = float16.to_f64
#
# # Do some math with float64 ...
#
# # Send the result back to the external API
# LibSome.set_a_float16(float64.to_f16)
# ```
struct Float16
  @value : Int16

  # Creates a new Float16 from the given Float32 value.
  def self.new(value : Float32)
    new LibIntrinsics.f32tof16(value)
  end

  # Creates a new Float16 from the given Float32 value.
  def self.new(value : Float64)
    new LibIntrinsics.f64tof16(value)
  end

  private def initialize(@value : Int16)
  end

  # Returns `true` if this Float16 is equal to the given value, `false` otherwise.
  def ==(other : Float32)
    to_f32 == other
  end

  # :ditto:
  def ==(other : Float64)
    to_f32 == other
  end

  # :ditto:
  def ==(other : Number)
    to_f64 == other
  end

  # Converts this Float16 to a Float32.
  def to_f32 : Float32
    LibIntrinsics.f16tof32(@value)
  end

  # Converts this Float16 to a Float64.
  def to_f64 : Float64
    LibIntrinsics.f16tof64(@value)
  end

  # :ditto:
  def to_f : Float64
    to_f64
  end

  # :nodoc:
  def inspect(io : IO) : Nil
    to_f64.to_s(io)
  end
end

struct Float64
  # Converts this Float64 to a Float16.
  def to_f16 : Float16
    Float16.new(self)
  end
end

struct Float32
  # Converts this Float32 to a Float16.
  def to_f16 : Float16
    Float16.new(self)
  end
end
