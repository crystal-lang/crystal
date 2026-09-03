require "./socket"

lib LibC
  struct SockaddrUn
    sun_family : SaFamilyT
    sun_path : Char[108]
  end
end
