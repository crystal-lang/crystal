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

  PKCS5_SALT_LEN     =  8
  EVP_MAX_KEY_LENGTH = 32
  EVP_MAX_IV_LENGTH  = 16

  CTRL_PUSH  =  6
  CTRL_POP   =  7
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

  fun evp_dss = EVP_dss : EVP_MD
  fun evp_dss1 = EVP_dss1 : EVP_MD
  fun evp_md4 = EVP_md4 : EVP_MD
  fun evp_md5 = EVP_md5 : EVP_MD
  fun evp_ripemd160 = EVP_ripemd160 : EVP_MD
  fun evp_sha = EVP_sha : EVP_MD
  fun evp_sha1 = EVP_sha1 : EVP_MD
  fun evp_sha224 = EVP_sha224 : EVP_MD
  fun evp_sha256 = EVP_sha256 : EVP_MD
  fun evp_sha384 = EVP_sha384 : EVP_MD
  fun evp_sha512 = EVP_sha512 : EVP_MD

  alias EVP_CIPHER = Void*
  alias EVP_CIPHER_CTX = Void*

  alias ASN1_OBJECT = Void*

  fun obj_txt2obj = OBJ_txt2obj(s : UInt8*, no_name : Int32) : ASN1_OBJECT
  fun obj_nid2sn = OBJ_nid2sn(n : Int32) : UInt8*
  fun obj_obj2nid = OBJ_obj2nid(obj : ASN1_OBJECT) : Int32
  fun asn1_object_free = ASN1_OBJECT_free(obj : ASN1_OBJECT)

  struct EVP_MD_CTX_Struct
    digest : EVP_MD
    engine : Void*
    flags : UInt32
    pctx : Void*
    update_fun : Void*
  end

  alias EVP_MD_CTX = EVP_MD_CTX_Struct*

  struct HMAC_CTX_Struct
    md : EVP_MD
    md_ctx : EVP_MD_CTX_Struct
    i_ctx : EVP_MD_CTX_Struct
    o_ctx : EVP_MD_CTX_Struct
    key_length : UInt32
    key : UInt8[128]
  end

  alias HMAC_CTX = HMAC_CTX_Struct*

  fun hmac_ctx_init = HMAC_CTX_init(ctx : HMAC_CTX)
  fun hmac_ctx_cleanup = HMAC_CTX_cleanup(ctx : HMAC_CTX)
  fun hmac_init_ex = HMAC_Init_ex(ctx : HMAC_CTX, key : Void*, len : Int32, md : EVP_MD, engine : Void*) : Int32
  fun hmac_update = HMAC_Update(ctx : HMAC_CTX, data : UInt8*, len : LibC::SizeT) : Int32
  fun hmac_final = HMAC_Final(ctx : HMAC_CTX, md : UInt8*, len : UInt32*) : Int32
  fun hmac_ctx_copy = HMAC_CTX_copy(dst : HMAC_CTX, src : HMAC_CTX) : Int32

  fun evp_get_digestbyname = EVP_get_digestbyname(name : UInt8*) : EVP_MD
  fun evp_md_ctx_create = EVP_MD_CTX_create : EVP_MD_CTX
  fun evp_digestinit_ex = EVP_DigestInit_ex(ctx : EVP_MD_CTX, type : EVP_MD, engine : Void*) : Int32
  fun evp_digestupdate = EVP_DigestUpdate(ctx : EVP_MD_CTX, data : UInt8*, count : LibC::SizeT) : Int32
  fun evp_md_ctx_destroy = EVP_MD_CTX_destroy(ctx : EVP_MD_CTX)
  fun evp_md_ctx_copy = EVP_MD_CTX_copy(dst : EVP_MD_CTX, src : EVP_MD_CTX) : Int32
  fun evp_md_ctx_md = EVP_MD_CTX_md(ctx : EVP_MD_CTX) : EVP_MD
  fun evp_md_size = EVP_MD_size(md : EVP_MD) : Int32
  fun evp_md_block_size = EVP_MD_block_size(md : EVP_MD) : LibC::Int
  fun evp_digestfinal_ex = EVP_DigestFinal_ex(ctx : EVP_MD_CTX, md : UInt8*, size : UInt32*) : Int32

  fun evp_get_cipherbyname = EVP_get_cipherbyname(name : UInt8*) : EVP_CIPHER
  fun evp_cipher_name = EVP_CIPHER_name(cipher : EVP_CIPHER) : UInt8*
  fun evp_cipher_nid = EVP_CIPHER_nid(cipher : EVP_CIPHER) : Int32
  fun evp_cipher_block_size = EVP_CIPHER_block_size(cipher : EVP_CIPHER) : Int32
  fun evp_cipher_key_length = EVP_CIPHER_key_length(cipher : EVP_CIPHER) : Int32
  fun evp_cipher_iv_length = EVP_CIPHER_iv_length(cipher : EVP_CIPHER) : Int32

  fun evp_cipher_ctx_new = EVP_CIPHER_CTX_new : EVP_CIPHER_CTX
  fun evp_cipher_ctx_free = EVP_CIPHER_CTX_free(ctx : EVP_CIPHER_CTX)
  fun evp_cipherinit_ex = EVP_CipherInit_ex(ctx : EVP_CIPHER_CTX, type : EVP_CIPHER, engine : Void*, key : UInt8*, iv : UInt8*, enc : Int32) : Int32
  fun evp_cipherupdate = EVP_CipherUpdate(ctx : EVP_CIPHER_CTX, out : UInt8*, outl : Int32*, in : UInt8*, inl : Int32) : Int32
  fun evp_cipherfinal_ex = EVP_CipherFinal_ex(ctx : EVP_CIPHER_CTX, out : UInt8*, outl : Int32*) : Int32
  fun evp_cipher_ctx_set_padding = EVP_CIPHER_CTX_set_padding(ctx : EVP_CIPHER_CTX, padding : Int32) : Int32
  fun evp_cipher_ctx_cipher = EVP_CIPHER_CTX_cipher(ctx : EVP_CIPHER_CTX) : EVP_CIPHER

  fun hmac = HMAC(evp : EVP_MD, key : Char*, key_len : Int,
                  d : Char*, n : SizeT, md : Char*, md_len : UInt*) : Char*

  fun rand_bytes = RAND_bytes(buf : Char*, num : Int) : Int
  fun err_get_error = ERR_get_error : ULong
  fun err_error_string = ERR_error_string(e : ULong, buf : Char*) : Char*
  fun openssl_add_all_algorithms = OPENSSL_add_all_algorithms_noconf
  fun err_load_crypto_strings = ERR_load_crypto_strings

  struct MD5Context
    a : UInt
    b : UInt
    c : UInt
    d : UInt
    nl : UInt
    nh : UInt
    data : UInt[16]
    num : UInt
  end

  fun md5_init = MD5_Init(c : MD5Context*) : Int
  fun md5_update = MD5_Update(c : MD5Context*, data : Void*, len : LibC::SizeT) : Int
  fun md5_final = MD5_Final(md : UInt8*, c : MD5Context*) : Int
  fun md5_transform = MD5_Transform(c : MD5Context*, b : UInt8*)
  fun md5 = MD5(data : UInt8*, lengh : LibC::SizeT, md : UInt8*) : UInt8*

  fun pkcs5_pbkdf2_hmac_sha1 = PKCS5_PBKDF2_HMAC_SHA1(pass : LibC::Char*, passlen : LibC::Int, salt : UInt8*, saltlen : LibC::Int, iter : LibC::Int, keylen : LibC::Int, out : UInt8*) : LibC::Int
end
