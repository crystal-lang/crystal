struct Float
  # :nodoc:
  # Source port of the floating-point part of fast_float for C++:
  # https://github.com/fastfloat/fast_float
  #
  # fast_float implements the C++17 `std::from_chars`, which accepts a subset of
  # the C `strtod` / `strtof`'s string format:
  #
  # - a leading plus sign is disallowed, but both fast_float and this port
  #   accept it;
  # - the exponent may be required or disallowed, depending on the format
  #   argument (this port always allows both);
  # - hexfloats are not enabled by default, and fast_float doesn't implement it;
  #   (https://github.com/fastfloat/fast_float/issues/124)
  # - hexfloats cannot start with `0x` or `0X`.
  #
  # The following is their license:
  #
  #   Licensed under either of Apache License, Version 2.0 or MIT license or
  #   BOOST license.
  #
  #   Unless you explicitly state otherwise, any contribution intentionally
  #   submitted for inclusion in this repository by you, as defined in the
  #   Apache-2.0 license, shall be triple licensed as above, without any
  #   additional terms or conditions.
  #
  # Main differences from the original fast_float:
  #
  # - Only `UC == UInt8` is implemented and tested, not the other wide chars;
  # - No explicit SIMD (the original mainly uses this for wide char strings).
  #
  # The following compile-time configuration is assumed:
  #
  # - #define FASTFLOAT_ALLOWS_LEADING_PLUS
  # - #define FLT_EVAL_METHOD 0
  module FastFloat
    # Current revision: https://github.com/fastfloat/fast_float/tree/v6.1.6

    def self.to_f64?(str : String, whitespace : Bool, strict : Bool) : Float64?
      value = uninitialized Float64
      start = str.to_unsafe
      finish = start + str.bytesize
      options = ParseOptionsT(typeof(str.to_unsafe.value)).new(format: :general)

      if whitespace
        start += str.calc_excess_left
        finish -= str.calc_excess_right
      end

      ret = BinaryFormat_Float64.new.from_chars_advanced(start, finish, pointerof(value), options)
      if ret.ec == Errno::NONE && (!strict || ret.ptr == finish)
        value
      end
    end

    def self.to_f32?(str : String, whitespace : Bool, strict : Bool) : Float32?
      value = uninitialized Float32
      start = str.to_unsafe
      finish = start + str.bytesize
      options = ParseOptionsT(typeof(str.to_unsafe.value)).new(format: :general)

      if whitespace
        start += str.calc_excess_left
        finish -= str.calc_excess_right
      end

      ret = BinaryFormat_Float32.new.from_chars_advanced(start, finish, pointerof(value), options)
      if ret.ec == Errno::NONE && (!strict || ret.ptr == finish)
        value
      end
    end
  end
end

require "./fast_float/parse_number"
