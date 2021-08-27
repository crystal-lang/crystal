lib LibC
  @[Flags]
  enum FlockOp
    SH = 0x1
    EX = 0x2
    NB = 0x4
    UN = 0x8
  end

  fun flock(fd : Int, op : FlockOp) : Int
end
