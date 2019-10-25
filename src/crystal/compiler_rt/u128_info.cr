@[Extern]
struct UInt128Info
  property low : UInt64 = 0_u64
  property high : UInt64 = 0_u64
end

@[Extern(union: true)]
struct UInt128RT
  macro [](high, low)
    %i_info = uninitialized UInt128RT
    %i_info.info.high = {{high}}.unsafe_as(UInt64)
    %i_info.info.low = {{low}}.unsafe_as(UInt64)
    %i_info
  end

  property all : UInt128 = 0_u128
  property info : UInt128Info = UInt128Info.new
end
