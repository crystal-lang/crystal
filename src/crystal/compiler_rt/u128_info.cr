lib CompilerRT
  struct UInt128Info
    low : UInt64
    high : Int64
  end

  union UI128
    all : UInt128
    info : UInt128Info
  end
end
