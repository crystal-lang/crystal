lib C
  fun rand : Int
  fun srand(seed : Int)
  fun time(t : Long) : Long
  fun fork : Int
  fun exit(status : Int)
  fun getenv(str : String) : String
end

def exit(status = 0)
  C.exit status
end
