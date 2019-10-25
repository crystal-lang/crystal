@[Extern]
struct Int128Info
  property high : Int64 = 0_i64
  property low : UInt64 = 0_u64
end

@[Extern(union: true)]
struct Int128RT
  macro [](high, low)
    %i_info = uninitialized Int128RT
    %i_info.info.high = {{high}}.unsafe_as(Int64)
    %i_info.info.low = {{low}}.unsafe_as(UInt64)
    %i_info
  end

  property all : Int128 = 0_i128
  property info : Int128Info = Int128Info.new
end
