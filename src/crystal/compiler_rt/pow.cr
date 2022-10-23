private macro __pow_impl(name, one, float_type)
  # :nodoc:
  # Ported from https://github.com/llvm/llvm-project/blob/2e9df860468425645dcd1b241c5dbf76c072e314/compiler-rt/lib/builtins
  fun {{name}}(a : {{float_type}}, b : Int32) : {{float_type}}
    recip = b < 0
    r = {{one}}

    loop do
      r *= a if b & 1 != 0
      b = b.unsafe_div 2
      break if b == 0
      a *= a
    end

    recip ? 1 / r : r
  end
end

__pow_impl(__powisf2, 1f32, Float32)
__pow_impl(__powidf2, 1f64, Float64)
