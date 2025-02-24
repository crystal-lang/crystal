# Supported library versions:
#
# * libpcre
#
# See https://crystal-lang.org/reference/man/required_libraries.html#regular-expression-engine
@[Link("pcre", pkg_config: "libpcre")]
{% if compare_versions(Crystal::VERSION, "1.11.0-dev") >= 0 %}
  @[Link(dll: "pcre.dll")]
{% end %}
lib LibPCRE
  alias Int = LibC::Int

  # Public options. Some are compile-time only, some are run-time only, and some
  # are both. Most of the compile-time options are saved with the compiled regex so
  # that they can be inspected during studying (and therefore JIT compiling). Note
  # that pcre_study() has its own set of options. Originally, all the options
  # defined here used distinct bits. However, almost all the bits in a 32-bit word
  # are now used, so in order to conserve them, option bits that were previously
  # only recognized at matching time (i.e. by pcre_exec() or pcre_dfa_exec()) may
  # also be used for compile-time options that affect only compiling and are not
  # relevant for studying or JIT compiling.

  # Some options for pcre_compile() change its behaviour but do not affect the
  # behaviour of the execution functions. Other options are passed through to the
  # execution functions and affect their behaviour, with or without affecting the
  # behaviour of pcre_compile().

  # Options that can be passed to pcre_compile() are tagged Cx below, with these
  # variants:

  # C1   Affects compile only
  # C2   Does not affect compile; affects exec, dfa_exec
  # C3   Affects compile, exec, dfa_exec
  # C4   Affects compile, exec, dfa_exec, study
  # C5   Affects compile, exec, study

  # Options that can be set for pcre_exec() and/or pcre_dfa_exec() are flagged with
  # E and D, respectively. They take precedence over C3, C4, and C5 settings passed
  # from pcre_compile(). Those that are compatible with JIT execution are flagged
  # with J.

  CASELESS       = 0x00000001
  MULTILINE      = 0x00000002
  DOTALL         = 0x00000004
  EXTENDED       = 0x00000008
  ANCHORED       = 0x00000010
  DOLLAR_ENDONLY = 0x00000020

  EXTRA           = 0x00000040 # C1
  NOTBOL          = 0x00000080 #    E D J
  NOTEOL          = 0x00000100 #    E D J
  UNGREEDY        = 0x00000200 # C1
  NOTEMPTY        = 0x00000400 #    E D J
  UTF8            = 0x00000800 # C4        )
  UTF16           = 0x00000800 # C4        ) Synonyms
  UTF32           = 0x00000800 # C4        )
  NO_AUTO_CAPTURE = 0x00001000 # C1
  NO_UTF8_CHECK   = 0x00002000 # C1 E D J  )
  NO_UTF16_CHECK  = 0x00002000 # C1 E D J  ) Synonyms
  NO_UTF32_CHECK  = 0x00002000 # C1 E D J  )
  AUTO_CALLOUT    = 0x00004000 # C1
  PARTIAL_SOFT    = 0x00008000 #    E D J  ) Synonyms
  PARTIAL         = 0x00008000 #    E D J  )

  # This pair use the same bit.
  NEVER_UTF    = 0x00010000 # C1        ) Overlaid
  DFA_SHORTEST = 0x00010000 #      D    ) Overlaid
  NOTBOS       = 0x00010000 #      D    ) Overlaid

  # This pair use the same bit.
  NO_AUTO_POSSESS = 0x00020000 # C1        ) Overlaid
  DFA_RESTART     = 0x00020000 #      D    ) Overlaid
  NOTEOS          = 0x00020000 #      D    ) Overlaid

  FIRSTLINE         = 0x00040000 # C3
  DUPNAMES          = 0x00080000 # C1
  NEWLINE_CR        = 0x00100000 # C3 E D
  NEWLINE_LF        = 0x00200000 # C3 E D
  NEWLINE_CRLF      = 0x00300000 # C3 E D
  NEWLINE_ANY       = 0x00400000 # C3 E D
  NEWLINE_ANYCRLF   = 0x00500000 # C3 E D
  BSR_ANYCRLF       = 0x00800000 # C3 E D
  BSR_UNICODE       = 0x01000000 # C3 E D
  JAVASCRIPT_COMPAT = 0x02000000 # C5
  NO_START_OPTIMIZE = 0x04000000 # C2 E D    ) Synonyms
  NO_START_OPTIMISE = 0x04000000 # C2 E D    )
  PARTIAL_HARD      = 0x08000000 #    E D J
  NOTEMPTY_ATSTART  = 0x10000000 #    E D J
  UCP               = 0x20000000 # C3
  NOTGPOS           = 0x40000000 # C3

  type Pcre = Void*
  type PcreExtra = Void*
  fun compile = pcre_compile(pattern : UInt8*, options : Int, errptr : UInt8**, erroffset : Int*, tableptr : Void*) : Pcre
  fun config = pcre_config(what : Int, where : Void*) : Int
  fun exec = pcre_exec(code : Pcre, extra : PcreExtra, subject : UInt8*, length : Int, offset : Int, options : Int, ovector : Int*, ovecsize : Int) : Int
  fun study = pcre_study(code : Pcre, options : Int, errptr : UInt8**) : PcreExtra
  fun free_study = pcre_free_study(extra : PcreExtra) : Void
  fun full_info = pcre_fullinfo(code : Pcre, extra : PcreExtra, what : Int, where : Int*) : Int
  fun get_stringnumber = pcre_get_stringnumber(code : Pcre, string_name : UInt8*) : Int
  fun get_stringtable_entries = pcre_get_stringtable_entries(code : Pcre, name : UInt8*, first : UInt8**, last : UInt8**) : Int
  fun version = pcre_version : LibC::Char*

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
