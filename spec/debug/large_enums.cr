enum SignedEnum : Int64
  X = 0x0123_4567_89ab_cdef_i64
end

enum UnsignedEnum : UInt64
  Y = 0xfedc_ba98_7654_3210_u64
end

x = SignedEnum::X
y = UnsignedEnum::Y
# print: x
# lldb-check: (SignedEnum) $0 = X
# print: y
# lldb-check: (UnsignedEnum) $1 = Y
debugger
