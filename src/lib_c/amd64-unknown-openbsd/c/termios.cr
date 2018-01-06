require "./sys/types"

lib LibC

  # Special Control Characters
  VEOF        =          0
  VEOL        =          1
  VEOL2       =          2
  VERASE      =          3
  VWERASE     =          4
  VKILL       =          5
  VREPRINT    =          6

  VINTR       =          8
  VQUIT       =          9
  VSUSP       =         10
  VDSUSP      =         11
  VSTART      =         12
  VSTOP       =         13
  VLNEXT      =         14
  VDISCARD    =         15
  VMIN        =         16
  VTIME       =         17
  VSTATUS     =         18

  NCCS        =         20

  # Input flags
  IGNBRK      = 0x00000001  # ignore BREAK condition
  BRKINT      = 0x00000002  # map BREAK to SIGINT
  IGNPAR      = 0x00000004  # ignore (discard) parity errors
  PARMRK      = 0x00000008  # mark parity and framing errors
  INPCK       = 0x00000010  # enable checking of parity errors
  ISTRIP      = 0x00000020  # strip 8th bit off chars
  INLCR       = 0x00000040  # map NL into CR
  IGNCR       = 0x00000080  # ignore CR
  ICRNL       = 0x00000100  # map CR to NL (ala CRMOD)
  IXON        = 0x00000200  # enable output flow control
  IXOFF       = 0x00000400  # enable input flow control
  IXANY       = 0x00000800  # any char will restart after stop
  IUCLC       = 0x00001000  # translate upper to lower case
  IMAXBEL     = 0x00002000  # ring bell on input queue full

  # Output flags
  OPOST       = 0x00000001  # enable following output processing
  ONLCR       = 0x00000002  # map NL to CR-NL (ala CRMOD)
  OXTABS      = 0x00000004  # expand tabs to spaces
  ONOEOT      = 0x00000008  # discard EOT's (^D) on output
  OCRNL       = 0x00000010  # map CR to NL
  OLCUC       = 0x00000020  # translate lower case to upper case
  ONOCR       = 0x00000040  # No CR output at column 0
  ONLRET      = 0x00000080  # NL performs the CR function

  # Control flags
  CIGNORE     = 0x00000001  # ignore control flags
  CSIZE       = 0x00000300  # character size mask
  CS5         = 0x00000000  # 5 bits (pseudo)
  CS6         = 0x00000100  # 6 bits
  CS7         = 0x00000200  # 7 bits
  CS8         = 0x00000300  # 8 bits
  CSTOPB      = 0x00000400  # send 2 stop bits
  CREAD       = 0x00000800  # enable receiver
  PARENB      = 0x00001000  # parity enable
  PARODD      = 0x00002000  # odd parity, else even
  HUPCL       = 0x00004000  # hang up on last close
  CLOCAL      = 0x00008000  # ignore modem status lines
  CRTSCTS     = 0x00010000  # RTS/CTS full-duplex flow control
  CRTS_IFLOW  = CRTSCTS     # XXX compat
  CCTS_OFLOW  = CRTSCTS     # XXX compat
  MDMBUF      = 0x00100000  # DTR/DCD hardware flow control
  CHWFLOW     = (MDMBUF|CRTSCTS)  # all types of hw flow control

  # "Local" flags
  ECHOKE      = 0x00000001  # visual erase for line kill
  ECHOE       = 0x00000002  # visually erase chars
  ECHOK       = 0x00000004  # echo NL after line kill
  ECHO        = 0x00000008  # enable echoing
  ECHONL      = 0x00000010  # echo NL even if ECHO is off
  ECHOPRT     = 0x00000020  # visual erase mode for hardcopy
  ECHOCTL     = 0x00000040  # echo control chars as ^(Char)
  ISIG        = 0x00000080  # enable signals INTR, QUIT, [D]SUSP
  ICANON      = 0x00000100  # canonicalize input lines
  ALTWERASE   = 0x00000200  # use alternate WERASE algorithm
  IEXTEN      = 0x00000400  # enable DISCARD and LNEXT
  EXTPROC     = 0x00000800  # external processing
  TOSTOP      = 0x00400000  # stop background jobs from output
  FLUSHO      = 0x00800000  # output being flushed (state)
  XCASE       = 0x01000000  # canonical upper/lower case
  NOKERNINFO  = 0x02000000  # no kernel output from VSTATUS
  PENDIN      = 0x20000000  # XXX retype pending input (state)
  NOFLSH      = 0x80000000  # don't flush after interrupt

  alias TcflagT = UInt
  alias CcT = Char
  alias SpeedT = UInt

  struct Termios
    c_iflag : TcflagT             # input flags
    c_oflag : TcflagT             # output flags
    c_cflag : TcflagT             # control flags
    c_lflag : TcflagT             # local flags
    c_cc : StaticArray(CcT, NCCS) # control chars
    c_ispeed : Int                # input speed
    c_ospeed : Int                # output speed
  end

  fun tcgetattr(x0 : Int, x1 : Termios*) : Int
  fun tcsetattr(x0 : Int, x1 : Int, x2 : Termios*) : Int
  fun cfmakeraw(x0 : Termios*) : Void
  # Commands passed to tcsetattr() for setting the termios structure.
  TCSANOW     =          0  # make change immediate
  TCSADRAIN   =          1  # drain output, then change
  TCSAFLUSH   =          2  # drain output, flush input
  TCSASOFT    =       0x10  # flag - don't alter h.w. state

  # Standard speeds
  B0          =          0
  B50         =         50
  B75         =         75
  B110        =        110
  B134        =        134
  B150        =        150
  B200        =        200
  B300        =        300
  B600        =        600
  B1200       =       1200
  B1800       =       1800
  B2400       =       2400
  B4800       =       4800
  B9600       =       9600
  B19200      =      19200
  B38400      =      38400
  B7200       =       7200
  B14400      =      14400
  B28800      =      28800
  B57600      =      57600
  B76800      =      76800
  B115200     =     115200
  B230400     =     230400
  EXTA        =      19200
  EXTB        =      38400

  TCIFLUSH    =          1
  TCOFLUSH    =          2
  TCIOFLUSH   =          3
  TCOOFF      =          1
  TCOON       =          2
  TCIOFF      =          3
  TCION       =          4

end
