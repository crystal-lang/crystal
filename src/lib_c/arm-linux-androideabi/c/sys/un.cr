require "./socket"

lib LibC
  struct SockaddrUn
    sun_family : UShort
    sun_path : StaticArray(Char, 108)
  end
end
