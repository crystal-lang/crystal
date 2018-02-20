require "./socket"

lib LibC
  struct SockaddrUn
    sun_len : Char                    # sockaddr len excluding NUL
    sun_family : SaFamilyT            # AF_UNIX
    sun_path : StaticArray(Char, 104) # path name (gag)
  end
end
