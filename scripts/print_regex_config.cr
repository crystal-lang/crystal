#! /usr/bin/env crystal

{% if Regex::Engine.resolve.name == "Regex::PCRE2" %}
  enum LibPCRE2::BSR : UInt32
    UNICODE = 1
    ANYCRLF = 2
  end

  @[Flags]
  enum LibPCRE2::COMPILED_WIDTHS : UInt32
    U8
    U16
    U32
    Unused
  end

  enum LibPCRE2::NEWLINE : UInt32
    CR      = 1
    LF      = 2
    CRLF    = 3
    ANY     = 4
    ANYCRLF = 5
    NUL     = 6
  end

  def config(kind : UInt32.class, what)
    where = uninitialized UInt32
    LibPCRE2.config(what, pointerof(where))
    where
  end

  def config(kind : Bool.class, what)
    config(UInt32, what) != 0
  end

  def config(kind : String.class, what)
    len = LibPCRE2.config(what, nil)
    if len > 0
      where = Bytes.new(len - 1)
      LibPCRE2.config(what, where)
      ret = String.new(where)
    end
    ret.inspect
  end

  def config(kind : Enum.class, what)
    kind.new(config(UInt32, what))
  end

  puts <<-EOS
  Using PCRE2 #{config(String, LibPCRE2::CONFIG_VERSION)}
  * PCRE2_CONFIG_BSR:               #{config(LibPCRE2::BSR, LibPCRE2::CONFIG_BSR)}
  * PCRE2_CONFIG_COMPILED_WIDTHS:   #{config(LibPCRE2::COMPILED_WIDTHS, LibPCRE2::CONFIG_COMPILED_WIDTHS)}
  * PCRE2_CONFIG_DEPTHLIMIT:        #{config(UInt32, LibPCRE2::CONFIG_DEPTHLIMIT)}
  * PCRE2_CONFIG_HEAPLIMIT:         #{config(UInt32, LibPCRE2::CONFIG_HEAPLIMIT)}
  * PCRE2_CONFIG_JIT:               #{config(Bool, LibPCRE2::CONFIG_JIT)}
  * PCRE2_CONFIG_JITTARGET:         #{config(String, LibPCRE2::CONFIG_JITTARGET)}
  * PCRE2_CONFIG_LINKSIZE:          #{config(UInt32, LibPCRE2::CONFIG_LINKSIZE)}
  * PCRE2_CONFIG_MATCHLIMIT:        #{config(UInt32, LibPCRE2::CONFIG_MATCHLIMIT)}
  * PCRE2_CONFIG_NEVER_BACKSLASH_C: #{config(Bool, LibPCRE2::CONFIG_NEVER_BACKSLASH_C)}
  * PCRE2_CONFIG_NEWLINE:           #{config(LibPCRE2::NEWLINE, LibPCRE2::CONFIG_NEWLINE)}
  * PCRE2_CONFIG_PARENSLIMIT:       #{config(UInt32, LibPCRE2::CONFIG_PARENSLIMIT)}
  * PCRE2_CONFIG_UNICODE:           #{config(Bool, LibPCRE2::CONFIG_UNICODE)}
  * PCRE2_CONFIG_UNICODE_VERSION:   #{config(String, LibPCRE2::CONFIG_UNICODE_VERSION)}
  EOS
{% else %}
  enum LibPCRE::BSR : LibC::Int
    UNICODE = 0
    ANYCRLF = 1
  end

  enum LibPCRE::NEWLINE : LibC::Int
    CR      = 0x000d
    LF      = 0x000a
    CRLF    = 0x0d0a
    ANYCRLF =     -2
    ANY     =     -1
  end

  lib LibPCRE
    CONFIG_UTF8                   =  0
    CONFIG_NEWLINE                =  1
    CONFIG_LINK_SIZE              =  2
    CONFIG_POSIX_MALLOC_THRESHOLD =  3
    CONFIG_MATCH_LIMIT            =  4
    CONFIG_STACKRECURSE           =  5
    CONFIG_UNICODE_PROPERTIES     =  6
    CONFIG_MATCH_LIMIT_RECURSION  =  7
    CONFIG_BSR                    =  8
    CONFIG_UTF16                  = 10
    CONFIG_JITTARGET              = 11
    CONFIG_UTF32                  = 12
    CONFIG_PARENS_LIMIT           = 13
  end

  def config(kind : LibC::Int.class, what)
    where = uninitialized LibC::Int
    LibPCRE.config(what, pointerof(where))
    where
  end

  def config(kind : LibC::ULong.class, what)
    where = uninitialized LibC::ULong
    LibPCRE.config(what, pointerof(where))
    where
  end

  def config(kind : Bool.class, what)
    config(LibC::Int, what) != 0
  end

  def config(kind : String.class, what)
    where = uninitialized LibC::Char*
    LibPCRE.config(what, pointerof(where))
    (where ? String.new(where) : nil).inspect
  end

  def config(kind : Enum.class, what)
    kind.new(config(LibC::Int, what))
  end

  puts <<-EOS
  Using PCRE #{String.new(LibPCRE.version).inspect}
  * PCRE_CONFIG_BSR:                    #{config(LibPCRE::BSR, LibPCRE::CONFIG_BSR)}
  * PCRE_CONFIG_JIT:                    #{config(Bool, LibPCRE::CONFIG_JIT)}
  * PCRE_CONFIG_JITTARGET:              #{config(String, LibPCRE::CONFIG_JITTARGET)}
  * PCRE_CONFIG_LINK_SIZE:              #{config(LibC::Int, LibPCRE::CONFIG_LINK_SIZE)}
  * PCRE_CONFIG_PARENS_LIMIT:           #{config(LibC::ULong, LibPCRE::CONFIG_PARENS_LIMIT)}
  * PCRE_CONFIG_MATCH_LIMIT:            #{config(LibC::ULong, LibPCRE::CONFIG_MATCH_LIMIT)}
  * PCRE_CONFIG_MATCH_LIMIT_RECURSION:  #{config(LibC::ULong, LibPCRE::CONFIG_MATCH_LIMIT_RECURSION)}
  * PCRE_CONFIG_NEWLINE:                #{config(LibPCRE::NEWLINE, LibPCRE::CONFIG_NEWLINE)}
  * PCRE_CONFIG_POSIX_MALLOC_THRESHOLD: #{config(LibC::Int, LibPCRE::CONFIG_POSIX_MALLOC_THRESHOLD)}
  * PCRE_CONFIG_STACKRECURSE:           #{config(Bool, LibPCRE::CONFIG_STACKRECURSE)}
  * PCRE_CONFIG_UTF16:                  #{config(Bool, LibPCRE::CONFIG_UTF16)}
  * PCRE_CONFIG_UTF32:                  #{config(Bool, LibPCRE::CONFIG_UTF32)}
  * PCRE_CONFIG_UTF8:                   #{config(Bool, LibPCRE::CONFIG_UTF8)}
  * PCRE_CONFIG_UNICODE_PROPERTIES:     #{config(Bool, LibPCRE::CONFIG_UNICODE_PROPERTIES)}
  EOS
{% end %}
