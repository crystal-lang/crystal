# Supported library versions:
#
# * zlib
#
# See https://crystal-lang.org/reference/man/required_libraries.html#other-stdlib-libraries
@[Link("z")]
{% if compare_versions(Crystal::VERSION, "1.11.0-dev") >= 0 %}
  @[Link(dll: "zlib1.dll")]
{% end %}
lib LibZ
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias Long = LibC::Long
  alias ULong = LibC::ULong
  alias SizeT = LibC::SizeT

  alias Bytef = UInt8

  fun zlibVersion : Char*
  fun adler32(adler : ULong, buf : Bytef*, len : UInt) : ULong
  fun adler32_combine(adler1 : ULong, adler2 : ULong, len : Long) : ULong
  fun crc32(crc : ULong, buf : Bytef*, len : UInt) : ULong
  fun crc32_combine(crc1 : ULong, crc2 : ULong, len : Long) : ULong

  alias AllocFunc = Void*, UInt, UInt -> Void*
  alias FreeFunc = (Void*, Void*) ->

  struct ZStream
    next_in : Bytef*
    avail_in : UInt
    total_in : ULong
    next_out : Bytef*
    avail_out : UInt
    total_out : ULong
    msg : Char*
    state : Void*
    zalloc : AllocFunc
    zfree : FreeFunc
    opaque : Void*
    data_type : Int
    adler : Long
    reserved : Long
  end

  # error codes
  enum Error
    OK            =  0
    STREAM_END    =  1
    NEED_DICT     =  2
    ERRNO         = -1
    STREAM_ERROR  = -2
    DATA_ERROR    = -3
    MEM_ERROR     = -4
    BUF_ERROR     = -5
    VERSION_ERROR = -6
  end

  enum Flush
    NO_FLUSH      = 0
    PARTIAL_FLUSH = 1
    SYNC_FLUSH    = 2
    FULL_FLUSH    = 3
    FINISH        = 4
    BLOCK         = 5
    TREES         = 6
  end

  MAX_BITS      = 15
  DEF_MEM_LEVEL =  8
  Z_DEFLATED    =  8

  fun deflateInit2 = deflateInit2_(stream : ZStream*, level : Int32, method : Int32,
                                   window_bits : Int32, mem_level : Int32, strategy : Int32,
                                   version : UInt8*, stream_size : Int32) : Error
  fun deflate(stream : ZStream*, flush : Flush) : Error
  fun deflateEnd(stream : ZStream*) : Error
  fun deflateReset(stream : ZStream*) : Error
  fun deflateSetDictionary(stream : ZStream*, dictionary : UInt8*, len : UInt) : Int

  fun inflateInit2 = inflateInit2_(stream : ZStream*, window_bits : Int32, version : UInt8*, stream_size : Int32) : Error
  fun inflate(stream : ZStream*, flush : Flush) : Error
  fun inflateEnd(stream : ZStream*) : Error
  fun inflateSetDictionary(stream : ZStream*, dictionary : UInt8*, len : UInt) : Error
  fun zError(error : Error) : UInt8*
end
