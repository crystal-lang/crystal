require "./socket"

lib LibC
  struct SockaddrUn
    sun_len : Char
    sun_family : SaFamilyT
    sun_path : StaticArray(Char, 104)
  end
end
