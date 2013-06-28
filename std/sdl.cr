lib LibSDL("SDL")
  INIT_TIMER       = 0x00000001_u32
  INIT_AUDIO       = 0x00000010_u32
  INIT_VIDEO       = 0x00000020_u32
  INIT_CDROM       = 0x00000100_u32
  INIT_JOYSTICK    = 0x00000200_u32
  INIT_NOPARACHUTE = 0x00100000_u32
  INIT_EVENTTHREAD = 0x01000000_u32
  INIT_EVERYTHING  = 0x0000FFFF_u32

  SWSURFACE = 0x00000000_u32
  HWSURFACE = 0x00000001_u32
  ASYNCBLIT = 0x00000004_u32

  ANYFORMAT  = 0x10000000_u32
  HWPALETTE  = 0x20000000_u32
  DOUBLEBUF  = 0x40000000_u32
  FULLSCREEN = 0x80000000_u32
  OPENGL     = 0x00000002_u32
  OPENGLBLIT = 0x0000000A_u32
  RESIZABLE  = 0x00000010_u32
  NOFRAME    = 0x00000020_u32

  NOEVENT         =  0_u8
  ACTIVEEVENT     =  1_u8
  KEYDOWN         =  2_u8
  KEYUP           =  3_u8
  MOUSEMOTION     =  4_u8
  MOUSEBUTTONDOWN =  5_u8
  MOUSEBUTTONUP   =  6_u8
  JOYAXISMOTION   =  7_u8
  JOYBALLMOTION   =  8_u8
  JOYHATMOTION    =  9_u8
  JOYBUTTONDOWN   = 10_u8
  JOYBUTTONUP     = 11_u8
  QUIT            = 12_u8
  SYSWMEVENT      = 13_u8
  EVENT_RESERVEDA = 14_u8
  EVENT_RESERVEDB = 15_u8
  VIDEORESIZE     = 16_u8
  VIDEOEXPOSE     = 17_u8
  EVENT_RESERVED2 = 18_u8
  EVENT_RESERVED3 = 19_u8
  EVENT_RESERVED4 = 20_u8
  EVENT_RESERVED5 = 21_u8
  EVENT_RESERVED6 = 22_u8
  EVENT_RESERVED7 = 23_u8
  USEREVENT       = 24_u8
  NUMEVENTS       = 32_u8

  HWACCEL     = 0x00000100_u32
  SRCCOLORKEY = 0x00001000_u32
  RLEACCELOK  = 0x00002000_u32
  RLEACCEL    = 0x00004000_u32
  SRCALPHA    = 0x00010000_u32
  PREALLOC    = 0x01000000_u32

  DISABLE = 0
  ENABLE = 1

  struct Color
    r, g, b, unused : UInt8
  end

  struct Rect
    x, y : Int16
    w, h : UInt16
  end

  struct Surface
    flags : UInt32
    format : Void* #TODO
    w, h : Int32
    pitch : UInt16
    pixels : Void*
    #TODO
  end

  enum Key
    ESCAPE = 27
    A = 97
    B = 98
    C = 99
    D = 100
    E = 101
    F = 102
    G = 103
    H = 104
    I = 105
    J = 106
    K = 107
    L = 108
    M = 109
    N = 110
    O = 111
    P = 112
    Q = 113
    R = 114
    S = 115
    T = 116
    U = 117
    V = 118
    W = 119
    X = 120
    Y = 121
    Z = 122
    UP = 273
    DOWN = 274
    RIGHT = 275
    LEFT = 276
  end

  struct KeySym
    scan_code : UInt8
    sym : UInt32
    #TODO
  end

  struct KeyboardEvent
    type : UInt8
    which : UInt8
    state : UInt8
    key_sym : KeySym
  end

  union Event
    type : UInt8
    key : KeyboardEvent
  end

  fun init = SDL_Init(flags : UInt32) : Int32
  fun get_error = SDL_GetError() : Char*
  fun quit = SDL_Quit() : Void
  fun set_video_mode = SDL_SetVideoMode(width : Int32, height : Int32, bpp : Int32, flags : UInt32) : Surface*
  fun delay = SDL_Delay(ms : UInt32) : Void
  fun poll_event = SDL_PollEvent(event : Event*) : Int32
  fun wait_event = SDL_WaitEvent(event : Event*) : Int32
  fun lock_surface = SDL_LockSurface(surface : Surface*) : Int32
  fun unlock_surface = SDL_UnlockSurface(surface : Surface*) : Void
  fun update_rect = SDL_UpdateRect(screen : Surface*, x : Int32, y : Int32, w : Int32, h : Int32) : Void
  fun show_cursor = SDL_ShowCursor(toggle : Int32) : Int32
  fun get_ticks = SDL_GetTicks : UInt32
  fun flip = SDL_Flip(screen : Surface*) : Int32
end

lib LibSDLMain("SDLMain")
end

module SDL
  def self.init(flags = LibSDL::INIT_EVERYTHING)
    if LibSDL.init(flags) != 0
      raise "Can't initialize SDL: #{error}"
    end
  end

  def self.set_video_mode(width, height, bpp, flags)
    surface = LibSDL.set_video_mode(width, height, bpp, flags)
    if surface.nil?
      raise "Can't set SDL video mode: #{error}"
    end
    Surface.new(surface, width, height, bpp)
  end

  def self.show_cursor
    LibSDL.show_cursor LibSDL::ENABLE
  end

  def self.hide_cursor
    LibSDL.show_cursor LibSDL::DISABLE
  end

  def self.error
    String.from_cstr LibSDL.get_error
  end

  def self.ticks
    LibSDL.get_ticks
  end

  def self.quit
    LibSDL.quit
  end

  def self.poll_events
    while LibSDL.poll_event(out event) == 1
      yield event
    end
  end

  class Surface
    def initialize(surface, width, height, bpp)
      @surface = surface
      @width = width
      @height = height
      @bpp = bpp
    end

    def width
      @width
    end

    def height
      @height
    end

    def bpp
      @bpp
    end

    def surface
      @surface
    end

    def lock
      LibSDL.lock_surface @surface
    end

    def unlock
      LibSDL.unlock_surface @surface
    end

    def update_rect(x, y, w, h)
      LibSDL.update_rect @surface, x, y, w, h
    end

    def flip
      LibSDL.flip @surface
    end

    def []=(offset, color)
      @surface.value.pixels.as(UInt32)[offset] = color.to_u32
    end

    def []=(x, y, color)
      self[y.to_i32 * @width + x.to_i32] = color
    end

    def offset(x, y)
      x.to_i32 + (y.to_i32 * @width)
    end

    def paint
      i = 0
      height.times do |y|
        width.times do |x|
          self[i] = yield x, y
          i += 1
        end
      end
    end
  end
end
