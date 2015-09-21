@[Link("z")]
lib LibZ
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias Long = LibC::Long
  alias ULong = LibC::ULong
  alias SizeT = LibC::SizeT
  alias Double = LibC::Double
  alias BitcntT = ULong

  alias Bytef = UInt8

  fun zlibVersion() : Char*
  fun adler32(adler: ULong, buf: Bytef*, len: UInt): ULong
  fun adler32_combine(adler1: ULong, adler2: ULong, len: Long) : ULong
  fun crc32(crc: ULong, buf: Bytef*, len: UInt) : ULong
  fun crc32_combine(crc1: ULong, crc2: ULong, len: Long) : ULong

  struct ZStream
    next_in: Bytef*
    avail_in: UInt
    total_in: ULong
    next_out: Bytef*
    avail_out: UInt
    total_out: ULong
    msg: Char*
    state: Void*
    zalloc: Void*
    zfree: Void*
    opaque: Void*
    data_type: Int
    adler: Long
    reserved: Long
  end

  struct GZHeader
    text: Int32
    time: UInt64
    xflags: Int32
    os: Int32
    extra: UInt8*
    extra_len: UInt32
    extra_max: UInt32
    name: UInt8*
    name_max: UInt32
    comment: UInt8*
    comm_max: UInt32
    hcrc: Int32
    done: Int32
  end

  enum Strategy
    FILTERED         = 1
    HUFFMAN_ONLY     = 2
    RLE              = 3
    FIXED            = 4
    DEFAULT_STRATEGY = 0
  end

  # compression level
  NO_COMPRESSION      = 0
  BEST_SPEED          = 1
  BEST_COMPRESSION    = 9
  DEFAULT_COMPRESSION = -1

  # error codes
  OK            = 0
  STREAM_END    = 1
  NEED_DICT     = 2
  ERRNO         = -1
  STREAM_ERROR  = -2
  DATA_ERROR    = -3
  MEM_ERROR     = -4
  BUF_ERROR     = -5
  VERSION_ERROR = -6

  enum Flush
    NO_FLUSH      = 0
    PARTIAL_FLUSH = 1
    SYNC_FLUSH    = 2
    FULL_FLUSH    = 3
    FINISH        = 4
    BLOCK         = 5
    TREES         = 6
  end

  MAX_BITS = 15
  DEF_MEM_LEVEL = 8
  Z_DEFLATED = 8

  fun deflateInit2 = deflateInit2_(stream: ZStream*, level: Int32, method: Int32,
                                   window_bits: Int32, mem_level: Int32, strategy: Strategy,
                                   version: UInt8*, stream_size: Int32) : Int32
  fun deflate(stream: ZStream*, flush: Flush) : Int32
  fun deflateEnd(stream: ZStream*) : Int32
  fun deflateReset(stream: ZStream*) : Int32
  fun deflateParams(stream: ZStream*, level: Int32, strategy: Strategy) : Int32
  fun deflateSetDictionary(stream: ZStream*, dictionary: UInt8*, len: UInt32) : Int32

  fun inflateInit2 = inflateInit2_(stream: ZStream*, window_bits: Int32, version: UInt8*, stream_size: Int32) : Int32
  fun inflate(stream: ZStream*, flush: Flush) : Int32
  fun inflateEnd(stream: ZStream*) : Int32
  fun inflateReset(stream: ZStream*) : Int32
  fun inflateSetDictionary(stream: ZStream*, dictionary: UInt8*, len: UInt32) : Int32

  alias GZFile = Void*

  fun gzdopen(fd: Int32, mode: UInt8*) : GZFile
  fun gzbuffer(file: GZFile, size: UInt32) : Int32
  fun gzsetparams(file: GZFile, level: Int32, strategy: Strategy) : Int32
  fun gzread(file: GZFile, buf: UInt8*, len: UInt32) : Int32
  fun gzwrite(file: GZFile, buf: UInt8*, len: UInt32) : Int32
  fun gzflush(file: GZFile, flush: Flush) : Int32
  fun gzseek(file: GZFile, offset: LibC::SizeT, whence: Int32) : Int32
  fun gzrewind(file: GZFile) : Int32
  fun gztell(file: GZFile) : LibC::SizeT
  fun gzoffset(file: GZFile) : LibC::SizeT
  fun gzeof(file: GZFile) : Int32
  fun gzdirect(file: GZFile) : Int32
  fun gzclose(file: GZFile) : Int32
  fun gzclose_r(file: GZFile) : Int32
  fun gzclose_w(file: GZFile) : Int32
  fun gzerror(file: GZFile, errnum: Int32*) : UInt8*
  fun gzclearerr(file: GZFile)
end
