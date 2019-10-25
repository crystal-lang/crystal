@[Extern]
struct Int128Info
  property low : UInt64 = 0_u64
  property high : Int64 = 0_i64
end

@[Extern(union: true)]
struct Int128RT
  property all : Int128 = 0_i128
  property info : Int128Info = Int128Info.new

  macro [](high, low)
    %i_info = uninitialized Int128RT
    %i_info.info.high = {{high}}.unsafe_as(Int64)
    %i_info.info.low = {{low}}.unsafe_as(UInt64)
    %i_info
  end

  macro [](high)
    %i_info = uninitialized Int128RT
    %i_info.all = {{high}}
    %i_info
  end

  def negate!
    self.info.high = self.info.high * -1
    self
  end

  def to_i128
    all
  end

  def debug
    printf("%x:%x\n", info.high, info.low)
  end
end
