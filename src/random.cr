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
    raise "incorrect value"
  end
end
