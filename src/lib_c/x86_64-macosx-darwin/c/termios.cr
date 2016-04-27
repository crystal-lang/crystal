require "./sys/types"

lib LibC
  VEOF      =          0
  VEOL      =          1
  VERASE    =          3
  VINTR     =          8
  VKILL     =          5
  VMIN      =         16
  VQUIT     =          9
  VSTART    =         12
  VSTOP     =         13
  VSUSP     =         10
  BRKINT    = 0x00000002
  ICRNL     = 0x00000100
  IGNBRK    = 0x00000001
  IGNCR     = 0x00000080
  IGNPAR    = 0x00000004
  INLCR     = 0x00000040
  INPCK     = 0x00000010
  ISTRIP    = 0x00000020
  IXANY     = 0x00000800
  IXOFF     = 0x00000400
  IXON      = 0x00000200
  PARMRK    = 0x00000008
  OPOST     = 0x00000001
  ONLCR     = 0x00000002
  OCRNL     = 0x00000010
  ONOCR     = 0x00000020
  ONLRET    = 0x00000040
  OFDEL     = 0x00020000
  OFILL     = 0x00000080
  CRDLY     = 0x00003000
  CR0       = 0x00000000
  CR1       = 0x00001000
  CR2       = 0x00002000
  CR3       = 0x00003000
  TABDLY    = 0x00000c04
  TAB0      = 0x00000000
  TAB1      = 0x00000400
  TAB2      = 0x00000800
  TAB3      = 0x00000004
  BSDLY     = 0x00008000
  BS0       = 0x00000000
  BS1       = 0x00008000
  VTDLY     = 0x00010000
  VT0       = 0x00000000
  VT1       = 0x00010000
  FFDLY     = 0x00004000
  FF0       = 0x00000000
  FF1       = 0x00004000
  NLDLY     = 0x00000300
  NL0       = 0x00000000
  NL1       = 0x00000100
  B0        =          0
  B50       =         50
  B75       =         75
  B110      =        110
  B134      =        134
  B150      =        150
  B200      =        200
  B300      =        300
  B600      =        600
  B1200     =       1200
  B1800     =       1800
  B2400     =       2400
  B4800     =       4800
  B9600     =       9600
  B19200    =      19200
  B38400    =      38400
  CSIZE     = 0x00000300
  CS5       = 0x00000000
  CS6       = 0x00000100
  CS7       = 0x00000200
  CS8       = 0x00000300
  CSTOPB    = 0x00000400
  CREAD     = 0x00000800
  PARENB    = 0x00001000
  PARODD    = 0x00002000
  HUPCL     = 0x00004000
  CLOCAL    = 0x00008000
  ECHO      = 0x00000008
  ECHOE     = 0x00000002
  ECHOK     = 0x00000004
  ECHONL    = 0x00000010
  ICANON    = 0x00000100
  IEXTEN    = 0x00000400
  ISIG      = 0x00000080
  NOFLSH    = 0x80000000
  TOSTOP    = 0x00400000
  TCSANOW   =          0
  TCSADRAIN =          1
  TCSAFLUSH =          2
  TCIFLUSH  =          1
  TCIOFLUSH =          3
  TCOFLUSH  =          2
  TCIOFF    =          3
  TCION     =          4
  TCOOFF    =          1
  TCOON     =          2

  alias CcT = Char
  alias SpeedT = ULong
  alias TcflagT = ULong

  struct Termios
    c_iflag : TcflagT
    c_oflag : TcflagT
    c_cflag : TcflagT
    c_lflag : TcflagT
    c_cc : StaticArray(CcT, 20)
    c_ispeed : SpeedT
    c_ospeed : SpeedT
  end

  fun tcgetattr(x0 : Int, x1 : Termios*) : Int
  fun tcsetattr(x0 : Int, x1 : Int, x2 : Termios*) : Int
  fun cfmakeraw(x0 : Termios*) : Void
end
