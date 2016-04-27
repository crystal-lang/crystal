require "./socket"

lib LibC
  struct SockaddrUn
    sun_family : SaFamilyT
    sun_path : StaticArray(Char, 108)
  end
end
