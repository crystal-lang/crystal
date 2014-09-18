@[Link("crypto")]
lib LibCrypto
  struct Bio
    method : Void*
    callback : (Void*, Int32, UInt8*, Int32, Int64, Int64) -> Int64
    cb_arg : UInt8*
    init : Int32
    shutdown : Int32
    flags : Int32
    retry_reason : Int32
    num : Int32
    ptr : Void*
    next_bio : Void*
    prev_bio : Void*
    references : Int32
    num_read : UInt64
    num_write : UInt64
  end

  CTRL_PUSH = 6
  CTRL_POP = 7
  CTRL_FLUSH = 11

  struct BioMethod
    type_id : Int32
    name : UInt8*
    bwrite : (Bio*, UInt8*, Int32) -> Int32
    bread : (Bio*, UInt8*, Int32) -> Int32
    bputs : (Bio*, UInt8*) -> Int32
    bgets : (Bio*, UInt8*, Int32) -> Int32
    ctrl : (Bio*, Int32, Int64, Void*) -> Int32
    create : Bio* -> Int32
    destroy : Bio* -> Int32
    callback_ctrl : (Bio*, Int32, Void*) -> Int64
  end

  fun bio_new = BIO_new(method : BioMethod*) : Bio*
  fun bio_free = BIO_free(bio : Bio*) : Int32

  struct MD5Context
    a : UInt32
    b : UInt32
    c : UInt32
    d : UInt32
    nl : UInt32
    nh : UInt32
    data : UInt32[16]
    num : UInt32
  end

  fun md5_init = MD5_Init(c : MD5Context*) : Int32
  fun md5_update = MD5_Update(c : MD5Context*, data : Void*, len : C::SizeT) : Int32
  fun md5_final = MD5_Final(md : UInt8*, c : MD5Context*) : Int32
  fun md5_transform = MD5_Transform(c : MD5Context*, b : UInt8*)
  fun md5 = MD5(data : UInt8*, lengh : C::SizeT, md : UInt8*) : UInt8*

  fun sha1 = SHA1(data : UInt8*, length : C::SizeT, md : UInt8*) : UInt8*
end
