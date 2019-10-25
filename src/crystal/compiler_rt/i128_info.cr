@[Extern]
struct Int128Info
  property low : UInt64 = 0_u64
  property high : Int64 = 0_i64
end

@[Extern(union: true)]
struct Int128RT
  property all = 0_i128
  property info = Int128Info.new
end
