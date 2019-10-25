@[Extern]
struct UInt128Info
  property low = 0_u64
  property high = 0_u64
end

@[Extern(union: true)]
struct UIntI128RT
  property all = 0_u128
  property info = UInt128Info.new
end

