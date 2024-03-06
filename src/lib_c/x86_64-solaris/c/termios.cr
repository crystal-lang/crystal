require "./sys/types"

lib LibC
  VINTR  =  0
  VQUIT  =  1
  VERASE =  2
  VKILL  =  3
  VEOF   =  4
  VEOL   =  5
  VMIN   =  4
  VTIME  =  5
  VSTART =  8
  VSTOP  =  9
  VSUSP  = 10

  IGNBRK = 0o000001
  BRKINT = 0o000002
  IGNPAR = 0o000004
  PARMRK = 0o000010
  INPCK  = 0o000020
  ISTRIP = 0o000040
  INLCR  = 0o000100
  IGNCR  = 0o000200
  ICRNL  = 0o000400
  IXON   = 0o002000
  IXANY  = 0o004000
  IXOFF  = 0o010000

  OPOST  = 0o000001
  ONLCR  = 0o000004
  OCRNL  = 0o000010
  ONOCR  = 0o000020
  ONLRET = 0o000040
  OFILL  = 0o000100
  OFDEL  = 0o000200
  NLDLY  = 0o000400
  NL0    =        0
  NL1    = 0o000400
  CRDLY  = 0o003000
  CR0    =        0
  CR1    = 0o001000
  CR2    = 0o002000
  CR3    = 0o003000
  TABDLY = 0o014000
  TAB0   =        0
  TAB1   = 0o004000
  TAB2   = 0o010000
  TAB3   = 0o014000
  BSDLY  = 0o020000
  BS0    =        0
  BS1    = 0o020000
  VTDLY  = 0o040000
  VT0    =        0
  VT1    = 0o040000
  FFDLY  = 0o100000
  FF0    =        0
  FF1    = 0o100000

  CSIZE  = 0o000060
  CS5    =        0
  CS6    = 0o000020
  CS7    = 0o000040
  CS8    = 0o000060
  CSTOPB = 0o000100
  CREAD  = 0o000200
  PARENB = 0o000400
  PARODD = 0o001000
  HUPCL  = 0o002000
  CLOCAL = 0o004000

  B0       =  0
  B50      =  1
  B75      =  2
  B110     =  3
  B134     =  4
  B150     =  5
  B200     =  6
  B300     =  7
  B600     =  8
  B1200    =  9
  B1800    = 10
  B2400    = 11
  B4800    = 12
  B9600    = 13
  B19200   = 14
  B38400   = 15
  B57600   = 16
  B76800   = 17
  B115200  = 18
  B153600  = 19
  B230400  = 20
  B307200  = 21
  B460800  = 22
  B921600  = 23
  B1000000 = 24
  B1152000 = 25
  B1500000 = 26
  B2000000 = 27
  B2500000 = 28
  B3000000 = 29
  B3500000 = 30
  B4000000 = 31

  ISIG   = 0o000001
  ICANON = 0o000002
  ECHO   = 0o000010
  ECHOE  = 0o000020
  ECHOK  = 0o000040
  ECHONL = 0o000100
  NOFLSH = 0o000200
  TOSTOP = 0o000400
  IEXTEN = 0o100000

  TCSANOW   = 0x540E
  TCSADRAIN = 0x540F
  TCSAFLUSH = 0x5410

  TCIFLUSH  = 0
  TCIOFLUSH = 2
  TCOFLUSH  = 1

  TCIOFF = 2
  TCION  = 3
  TCOOFF = 0
  TCOON  = 1

  alias CcT = UChar
  alias SpeedT = UInt
  alias TcflagT = UInt

  struct Termios
    c_iflag : TcflagT
    c_oflag : TcflagT
    c_cflag : TcflagT
    c_lflag : TcflagT
    c_cc : CcT[19]
  end

  fun tcgetattr(x0 : Int, x1 : Termios*) : Int
  fun tcsetattr(x0 : Int, x1 : Int, x2 : Termios*) : Int
end
