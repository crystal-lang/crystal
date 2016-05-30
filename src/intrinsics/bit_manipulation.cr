
# Bit Manipulation Intrinsics
#
# See http://llvm.org/docs/LangRef.html#bit-manipulation-intrinsics
module Intrinsics::BitManipulation

  lib Lib

    # http://llvm.org/docs/LangRef.html#llvm-ctpop-intrinsic
    fun ctpop_i8 = "llvm.ctpop.i8"(src : Int8) : Int8
    fun ctpop_i16 = "llvm.ctpop.i16"(src : Int16) : Int16
    fun ctpop_i32 = "llvm.ctpop.i32"(src : Int32) : Int32
    fun ctpop_i64 = "llvm.ctpop.i64"(src : Int64) : Int64

    # http://llvm.org/docs/LangRef.html#llvm-bswap-intrinsics
    fun bswap_i16 = "llvm.bswap.i16"(value : Int16) : Int16
    fun bswap_i32 = "llvm.bswap.i32"(value : Int32) : Int32
    fun bswap_i64 = "llvm.bswap.i64"(value : Int64) : Int64

  end

  @[AlwaysInline]
  def ctpop(src : Int8) : Int8
    Lib.ctpop_i8(src)
  end

  @[AlwaysInline]
  def ctpop(src : UInt8) : UInt8
    Lib.ctpop_i8(pointerof(src).as(Int8*).value).to_u8
  end

  @[AlwaysInline]
  def ctpop(src : Int16) : Int16
    Lib.ctpop_i16(src)
  end

  @[AlwaysInline]
  def ctpop(src : UInt16) : UInt16
    Lib.ctpop_i16(pointerof(src).as(Int16*).value).to_u16
  end

  @[AlwaysInline]
  def ctpop(src : Int32) : Int32
    Lib.ctpop_i32(src)
  end

  @[AlwaysInline]
  def ctpop(src : UInt32) : UInt32
    Lib.ctpop_i32(pointerof(src).as(Int32*).value).to_u32
  end

  @[AlwaysInline]
  def ctpop(src : Int64) : Int64
    Lib.ctpop_i64(src)
  end

  @[AlwaysInline]
  def ctpop(src : UInt64) : UInt64
    Lib.ctpop_i64(pointerof(src).as(Int64*).value).to_u64
  end

  @[AlwaysInline]
  def bswap(value : Int16) : Int16
    Lib.bswap_i16(value)
  end

  @[AlwaysInline]
  def bswap(value : Int32) : Int32
    Lib.bswap_i32(value)
  end

  @[AlwaysInline]
  def bswap(value : Int64) : Int64
    Lib.bswap_i64(value)
  end

  @[AlwaysInline]
  def bswap(value : UInt16) : UInt16
    pointerof(Lib.bswap_i16(pointerof(value).as(Int16*).value)).as(UInt16*).value
  end

  @[AlwaysInline]
  def bswap(value : UInt32) : UInt32
    pointerof(Lib.bswap_i32(pointerof(value).as(Int32*).value)).as(UInt32*).value
  end

  @[AlwaysInline]
  def bswap(value : UInt64) : UInt64
    pointerof(Lib.bswap_i64(pointerof(value).as(Int64*).value)).as(UInt64*).value
  end

  @[AlwaysInline]
  def bswap(value : Float32) : Float32
    pointerof(Lib.bswap_i32(pointerof(value).as(Int32*).value)).as(Float32*).value
  end

  @[AlwaysInline]
  def bswap(value : Float64) : Float64
    pointerof(Lib.bswap_i64(pointerof(value).as(Int64*).value)).as(Float64*).value
  end

end
