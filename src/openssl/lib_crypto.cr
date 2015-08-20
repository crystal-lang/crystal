@[Link("crypto")]
lib LibCrypto
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias Long = LibC::Long
  alias ULong = LibC::ULong
  alias SizeT = LibC::SizeT

  struct Bio
    method : Void*
    callback : (Void*, Int, Char*, Int, Long, Long) -> Long
    cb_arg : Char*
    init : Int
    shutdown : Int
    flags : Int
    retry_reason : Int
    num : Int
    ptr : Void*
    next_bio : Void*
    prev_bio : Void*
    references : Int
    num_read : ULong
    num_write : ULong
  end

  CTRL_PUSH = 6
  CTRL_POP = 7
  CTRL_FLUSH = 11

  alias BioMethodWrite = (Bio*, Char*, Int) -> Int
  alias BioMethodRead = (Bio*, Char*, Int) -> Int
  alias BioMethodPuts = (Bio*, Char*) -> Int
  alias BioMethodGets = (Bio*, Char*, Int) -> Int
  alias BioMethodCtrl = (Bio*, Int, Long, Void*) -> Long
  alias BioMethodCreate = Bio* -> Int
  alias BioMethodDestroy = Bio* -> Int
  alias BioMethodCallbackCtrl = (Bio*, Int, Void*) -> Long

  struct BioMethod
    type_id : Int
    name : Char*
    bwrite : BioMethodWrite
    bread : BioMethodRead
    bputs : BioMethodPuts
    bgets : BioMethodGets
    ctrl : BioMethodCtrl
    create : BioMethodCreate
    destroy : BioMethodDestroy
    callback_ctrl : BioMethodCallbackCtrl
  end

  fun bio_new = BIO_new(method : BioMethod*) : Bio*
  fun bio_free = BIO_free(bio : Bio*) : Int

  fun sha1 = SHA1(data : Char*, length : SizeT, md : Char*) : Char*

  type EVP_MD = Void*

  fun evp_dss       = EVP_dss : EVP_MD
  fun evp_dss1      = EVP_dss1 : EVP_MD
  fun evp_md4       = EVP_md4 : EVP_MD
  fun evp_md5       = EVP_md5 : EVP_MD
  fun evp_ripemd160 = EVP_ripemd160 : EVP_MD
  fun evp_sha       = EVP_sha : EVP_MD
  fun evp_sha1      = EVP_sha1 : EVP_MD
  fun evp_sha224    = EVP_sha224 : EVP_MD
  fun evp_sha256    = EVP_sha256 : EVP_MD
  fun evp_sha384    = EVP_sha384 : EVP_MD
  fun evp_sha512    = EVP_sha512 : EVP_MD

  fun hmac = HMAC(evp : EVP_MD, key : Char*, key_len : Int,
                  d : Char*, n : SizeT, md : Char*, md_len : UInt*) : Char*

  fun rand_bytes = RAND_bytes(buf : Char*, num : Int) : Int
  fun err_get_error = ERR_get_error : ULong
  fun err_error_string = ERR_error_string(e : ULong, buf : Char*) : Char*
end
