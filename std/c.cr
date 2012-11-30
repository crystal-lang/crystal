lib C
  fun rand : Int
  fun srand(seed : Int)
  fun time(t : Long) : Long
  fun fork : Int
  fun exit(status : Int)
end

def exit(status = 0)
  C.exit status
end
