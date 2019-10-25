@[Extern]
struct UInt128Info
  property low : UInt64 = 0_u64
  property high : UInt64 = 0_u64
end

@[Extern(union: true)]
struct UInt128RT
  property all : UInt128 = 0_u128
  property info : UInt128Info = UInt128Info.new
end
