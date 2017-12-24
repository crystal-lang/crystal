require "c/corecrt"

lib LibC
  struct Utimbuf64
    actime : Time64T
    modtime : Time64T
  end

  fun _wutime64(filename : WCHAR*, times : Utimbuf64*) : Int
end
