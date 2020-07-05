lib LibC
  # struct IpMreq
  #   imr_multiaddr : IN_ADDR
  #   imr_interface : IN_ADDR
  # end

  # https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/
  alias ADDRESS_FAMILY = UShort

  UNIX_PATH_MAX = 108

  struct SockaddrUn
    sun_family : ADDRESS_FAMILY
    sun_path : StaticArray(Char, UNIX_PATH_MAX)
  end
end
