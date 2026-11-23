lib LibC
  POLLIN   = 0x0001
  POLLOUT  = 0x0002
  POLLERR  = 0x1000
  POLLHUP  = 0x2000
  POLLNVAL = 0x4000

  alias NfdsT = ULong

  struct Pollfd
    fd : Int
    events : Short
    revents : Short
  end

  fun poll(x0 : Pollfd*, x1 : NfdsT, x2 : Int) : Int
end
