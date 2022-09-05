require "./socket"

lib LibC
  struct SockaddrUn
    sun_len : UInt8
    sun_family : SaFamilyT
    sun_path : StaticArray(Char, 104)
  end
end
