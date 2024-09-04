require "./ws2def"

lib LibC
  struct SockaddrUn
    sun_family : ADDRESS_FAMILY
    sun_path : Char[108]
  end
end
