require "time"

lib C
  RAND_MAX = 2147483647

  fun srand(seed : UInt32)
  fun rand() : Int32
end

C.srand(Time.now.to_i.to_u32)

def srand(x)
  C.srand(x.to_u32)
end

def rand()
  C.rand / C::RAND_MAX.to_f
end

def rand(x : Int)
  if x > 0
    C.rand % x
  else
    raise "incorrect rand value: #{x}"
  end
end

def rand(x : Range(Int32, Int32))
  span = x.end - x.begin
  span += 1 unless x.excludes_end?
  if span > 0
    x.begin + rand(span)
  else
    raise "incorrect rand value: #{x}"
  end
end
