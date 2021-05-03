lib LibC
  alias AddressFamily = UShort

  struct SockaddrUn
    sun_family : AddressFamily
    sun_path : Char[108]
  end
end
