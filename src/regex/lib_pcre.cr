@[Link("pcre")]
lib LibPCRE
  alias Int = LibC::Int

  CASELESS      = 0x00000001
  MULTILINE     = 0x00000002
  DOTALL        = 0x00000004
  EXTENDED      = 0x00000008
  ANCHORED      = 0x00000010
  UTF8          = 0x00000800
  NO_UTF8_CHECK = 0x00002000
  DUPNAMES      = 0x00080000
  UCP           = 0x20000000

  type Pcre = Void*
  type PcreExtra = Void*
  fun compile = pcre_compile(pattern : UInt8*, options : Int, errptr : UInt8**, erroffset : Int*, tableptr : Void*) : Pcre
  fun config = pcre_config(what : Int, where : Int*) : Int
  fun exec = pcre_exec(code : Pcre, extra : PcreExtra, subject : UInt8*, length : Int, offset : Int, options : Int, ovector : Int*, ovecsize : Int) : Int
  fun study = pcre_study(code : Pcre, options : Int, errptr : UInt8**) : PcreExtra
  fun free_study = pcre_free_study(extra : PcreExtra) : Void
  fun full_info = pcre_fullinfo(code : Pcre, extra : PcreExtra, what : Int, where : Int*) : Int
  fun get_stringnumber = pcre_get_stringnumber(code : Pcre, string_name : UInt8*) : Int
  fun get_stringtable_entries = pcre_get_stringtable_entries(code : Pcre, name : UInt8*, first : UInt8**, last : UInt8**) : Int

  CONFIG_JIT = 9

  STUDY_JIT_COMPILE = 0x0001

  INFO_CAPTURECOUNT  = 2
  INFO_NAMEENTRYSIZE = 7
  INFO_NAMECOUNT     = 8
  INFO_NAMETABLE     = 9

  $free = pcre_free : Void* ->

  # Exec-time and get/set-time error codes
  enum Error
    NOMATCH         =  -1
    NULL            =  -2
    BADOPTION       =  -3
    BADMAGIC        =  -4
    UNKNOWN_OPCODE  =  -5
    UNKNOWN_NODE    =  -5 # For backward compatibility
    NOMEMORY        =  -6
    NOSUBSTRING     =  -7
    MATCHLIMIT      =  -8
    CALLOUT         =  -9 # Never used by PCRE itself
    BADUTF8         = -10 # Same for 8/16/32
    BADUTF16        = -10 # Same for 8/16/32
    BADUTF32        = -10 # Same for 8/16/32
    BADUTF8_OFFSET  = -11 # Same for 8/16
    BADUTF16_OFFSET = -11 # Same for 8/16
    PARTIAL         = -12
    BADPARTIAL      = -13
    INTERNAL        = -14
    BADCOUNT        = -15
    DFA_UITEM       = -16
    DFA_UCOND       = -17
    DFA_UMLIMIT     = -18
    DFA_WSSIZE      = -19
    DFA_RECURSE     = -20
    RECURSIONLIMIT  = -21
    NULLWSLIMIT     = -22 # No longer actually used
    BADNEWLINE      = -23
    BADOFFSET       = -24
    SHORTUTF8       = -25
    SHORTUTF16      = -25 # Same for 8/16
    RECURSELOOP     = -26
    JIT_STACKLIMIT  = -27
    BADMODE         = -28
    BADENDIANNESS   = -29
    DFA_BADRESTART  = -30
    JIT_BADOPTION   = -31
    BADLENGTH       = -32
    UNSET           = -33
  end
end
