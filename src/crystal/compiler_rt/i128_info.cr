lib CompilerRT
  struct Int128Info
    low : UInt64
    high : Int64
  end

  union I128
    all : Int128
    info : Int128Info
  end
end
