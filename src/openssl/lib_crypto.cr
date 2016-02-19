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

  alias BIO = Bio*

  PKCS5_SALT_LEN     =  8
  EVP_MAX_KEY_LENGTH = 32
  EVP_MAX_IV_LENGTH  = 16

  CTRL_PUSH  =  6
  CTRL_POP   =  7
  CTRL_FLUSH = 11

  BIO_CTRL_RESET = 1

  alias BioMethodWrite = (BIO, Char*, Int) -> Int
  alias BioMethodRead = (BIO, Char*, Int) -> Int
  alias BioMethodPuts = (BIO, Char*) -> Int
  alias BioMethodGets = (BIO, Char*, Int) -> Int
  alias BioMethodCtrl = (BIO, Int, Long, Void*) -> Long
  alias BioMethodCreate = BIO -> Int
  alias BioMethodDestroy = BIO -> Int
  alias BioMethodCallbackCtrl = (BIO, Int, Void*) -> Long

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

  alias BIO_METHOD = BioMethod*

  fun bio_s_mem = BIO_s_mem : BIO_METHOD
  fun bio_new = BIO_new(type : BIO_METHOD) : BIO
  fun bio_free = BIO_free(bio : BIO) : Int
  fun bio_free_all = BIO_free_all(bio : BIO)
  fun bio_read = BIO_read(bio : BIO, data : UInt8*, len : Int32) : Int32
  fun bio_write = BIO_write(bio : BIO, data : UInt8*, len : Int32) : Int32

  fun bio_ctrl = BIO_ctrl(bio : BIO, cmd : Int, larg : Long, parg : Void*) : Long

  fun err_error_string = ERR_error_string(e : ULong, buf : Char*) : Char*
  fun get_error = ERR_get_error : ULong
  fun cleanse = OPENSSL_cleanse(ptr : Char*, len : UInt)

  fun sha1 = SHA1(data : Char*, length : SizeT, md : Char*) : Char*

  alias EVP_MD = Void*
  alias EVP_CIPHER = Void*
  alias EVP_CIPHER_CTX = Void*

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

  fun evp_md_ctx_create = EVP_MD_CTX_create : EVP_MD_CTX
  fun evp_get_digestbyname = EVP_get_digestbyname(name : UInt8*) : EVP_MD
  fun evp_digestinit_ex = EVP_DigestInit_ex(ctx : EVP_MD_CTX, type : EVP_MD, engine : Void*) : Int32
  fun evp_md_ctx_destroy = EVP_MD_CTX_destroy(ctx : EVP_MD_CTX)
  fun evp_md_ctx_md = EVP_MD_CTX_md(ctx : EVP_MD_CTX) : EVP_MD
  fun evp_digestupdate = EVP_DigestUpdate(ctx : EVP_MD_CTX, data : UInt8*, count : LibC::SizeT) : Int32
  fun evp_md_size = EVP_MD_size(md : EVP_MD) : Int32
  fun evp_digestfinal_ex = EVP_DigestFinal_ex(ctx : EVP_MD_CTX, md : UInt8*, size : UInt32*) : Int32
  fun evp_md_block_size = EVP_MD_block_size(md : EVP_MD) : LibC::Int
  fun evp_md_ctx_copy = EVP_MD_CTX_copy(dst : EVP_MD_CTX, src : EVP_MD_CTX) : Int32

  fun evp_bytestokey = EVP_BytesToKey(ctype : EVP_CIPHER, md : EVP_MD, salt : UInt8*, pass : UInt8*, passlen : Int32, iter : Int32, key : UInt8*, iv : UInt8*) : Int32

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

  alias EVP_PKEY = Void*

  fun evp_pkey_size = EVP_PKEY_size(pkey : EVP_PKEY) : Int32
  fun evp_signfinal = EVP_SignFinal(ctx : EVP_MD_CTX, sigret : UInt8*, siglen : UInt32*, pkey : EVP_PKEY) : Int32
  fun evp_verifyfinal = EVP_VerifyFinal(ctx : EVP_MD_CTX, sigbuf : UInt8*, siglen : UInt32, pkey : EVP_PKEY) : Int32
  fun evp_pkey_new = EVP_PKEY_new : EVP_PKEY
  fun evp_pkey_free = EVP_PKEY_free(pkey : EVP_PKEY)

  NID_undef         =   0
  NID_rsaEncryption =   6
  NID_dsa           = 116

  fun evp_pkey_assign = EVP_PKEY_assign(pkey : EVP_PKEY, type : Int32, key : Void*) : Int32

  fun hmac = HMAC(evp : EVP_MD, key : Char*, key_len : Int,
                  d : Char*, n : SizeT, md : Char*, md_len : UInt*) : Char*

  fun hmac_ctx_init = HMAC_CTX_init(ctx : HMAC_CTX)
  fun hmac_ctx_cleanup = HMAC_CTX_cleanup(ctx : HMAC_CTX)
  fun hmac_init_ex = HMAC_Init_ex(ctx : HMAC_CTX, key : Void*, len : Int32, md : EVP_MD, engine : Void*) : Int32
  fun hmac_update = HMAC_Update(ctx : HMAC_CTX, data : UInt8*, len : LibC::SizeT) : Int32
  fun hmac_final = HMAC_Final(ctx : HMAC_CTX, md : UInt8*, len : UInt32*) : Int32
  fun hmac_ctx_copy = HMAC_CTX_copy(dst : HMAC_CTX, src : HMAC_CTX) : Int32

  alias ASN1_OBJECT = Void*
  alias ASN1_INTEGER = Void*
  alias ASN1_TIME = Void*

  fun obj_txt2obj = OBJ_txt2obj(s : UInt8*, no_name : Int32) : ASN1_OBJECT
  fun obj_nid2sn = OBJ_nid2sn(n : Int32) : UInt8*
  fun obj_obj2nid = OBJ_obj2nid(obj : ASN1_OBJECT) : Int32
  fun asn1_object_free = ASN1_OBJECT_free(obj : ASN1_OBJECT)
  fun asn1_dup = ASN1_dup(i2d : Void*, d2i_of_void : Void*, x : Void*) : Void*
  fun i2a_asn1_object = i2a_ASN1_OBJECT(bio : BIO, asn : ASN1_OBJECT) : Int32
  fun obj_txt2obj = OBJ_txt2obj(s : UInt8*, no_name : Int32) : ASN1_OBJECT
  fun asn1_object_size = ASN1_object_size(constructed : Int32, length : Int32, tag : Int32) : Int32
  fun asn1_put_object = ASN1_put_object(pp : UInt8**, constructed : Int32, length : Int32, tag : Int32, xclass : Int32)
  fun asn1_integer_set = ASN1_INTEGER_set(a : ASN1_INTEGER, v : Int64) : Int32
  fun asn1_time_free = ASN1_TIME_free(t : ASN1_TIME)
  fun x509_gmtime_adj = X509_gmtime_adj(t : ASN1_TIME, adj : Int64) : ASN1_TIME

  alias PasswordCallback = (UInt8*, Int32, Int32, Void*) -> Int32

  alias RSA = Void*

  fun rsa_generate_key = RSA_generate_key(bits : Int32, e : UInt32, cb : (Int32, Int32, Void*) ->, ud : Void*) : RSA
  fun rsapublickey_dup = RSAPublicKey_dup(rsa : RSA) : RSA
  fun evp_pkey_get1_rsa = EVP_PKEY_get1_RSA(pk : EVP_PKEY) : RSA
  fun rsa_print = RSA_print(bio : BIO, rsa : RSA, off : Int32) : Int32
  fun i2d_rsaprivatekey = i2d_RSAPrivateKey(rsa : RSA, buf : UInt8**) : Int32
  fun i2d_rsa_pubkey = i2d_RSA_PUBKEY(rsa : RSA, buf : UInt8**) : Int32
  fun rsa_size = RSA_size(rsa : RSA) : Int32

  enum Padding
    PKCS1_PADDING      = 1
    SSLV23_PADDING     = 2
    NO_PADDING         = 3
    PKCS1_OAEP_PADDING = 4
    X931_PADDING       = 5
    PKCS1_PSS_PADDING  = 6
  end

  fun err_get_error = ERR_get_error : ULong
  fun err_error_string = ERR_error_string(e : ULong, buf : Char*) : Char*
  fun openssl_add_all_algorithms = OPENSSL_add_all_algorithms_noconf
  fun err_load_crypto_strings = ERR_load_crypto_strings

  fun rsa_public_encrypt = RSA_public_encrypt(flen : Int32, from : UInt8*, to : UInt8*, rsa : RSA, p : Padding) : Int32
  fun rsa_public_decrypt = RSA_public_decrypt(flen : Int32, from : UInt8*, to : UInt8*, rsa : RSA, p : Padding) : Int32
  fun rsa_private_encrypt = RSA_private_encrypt(flen : Int32, from : UInt8*, to : UInt8*, rsa : RSA, p : Padding) : Int32
  fun rsa_private_decrypt = RSA_private_decrypt(flen : Int32, from : UInt8*, to : UInt8*, rsa : RSA, p : Padding) : Int32

  fun pem_read_bio_privatekey = PEM_read_bio_PrivateKey(bio : BIO, pk : EVP_PKEY*, cb : PasswordCallback, user_data : Void*) : EVP_PKEY
  fun pem_write_bio_rsaprivatekey = PEM_write_bio_RSAPrivateKey(bio : BIO, rsa : RSA, enc : EVP_CIPHER,
                                                                kstr : UInt8*, klen : Int32, cb : PasswordCallback, user_data : Void*) : Int32
  fun pem_write_bio_rsa_pubkey = PEM_write_bio_RSA_PUBKEY(bio : BIO, rsa : RSA)

  fun rand_bytes = RAND_bytes(buf : UInt8*, num : Int32) : Int32

  alias DSA = Void*

  fun dsa_generate_parameters = DSA_generate_parameters(bit : Int32, seed : UInt8*, seed_len : Int32, counter_ret : Int32*,
                                                        h_ret : UInt64*, cb : Void*, user_data : Void*) : DSA
  fun dsa_generate_key = DSA_generate_key(dsa : DSA) : Int32
  fun dsa_free = DSA_free(dsa : DSA)
  fun pem_read_bio_dsaprivatekey = PEM_read_bio_DSAPrivateKey(bio : BIO, dsa : DSA*, cb : PasswordCallback, user_data : Void*) : DSA
  fun d2i_dsaprivatekey_bio = d2i_DSAPrivateKey_bio(bio : BIO, dsa : DSA*) : DSA
  fun d2i_dsa_pubkey_bio = d2i_DSA_PUBKEY_bio(bio : BIO, dsa : DSA*) : DSA

  fun pem_write_bio_dsaprivatekey = PEM_write_bio_DSAPrivateKey(bio : BIO, dsa : DSA, c : EVP_CIPHER, kstr : UInt8*, klen : Int32,
                                                                cb : PasswordCallback, user_data : Void*) : Int32
  fun pem_write_bio_dsa_pubkey = PEM_write_bio_DSA_PUBKEY(bio : BIO, dsa : DSA) : Int32
  fun evp_pkey_get1_dsa = EVP_PKEY_get1_DSA(pkey : EVP_PKEY) : DSA
  fun i2d_dsaprivatekey = i2d_DSAPrivateKey(dsa : DSA, pp : UInt8**) : Int32
  fun i2d_dsa_pubkey = i2d_DSA_PUBKEY(dsa : DSA, pp : UInt8**) : Int32
  fun dsa_size = DSA_size(dsa : DSA) : Int32
  fun dsa_sign = DSA_sign(type : Int32, dgst : UInt8*, dlen : Int32, sig : UInt8*, siglen : Int32*, dsa : DSA) : Int32
  fun dsa_verify = DSA_verify(type : Int32, dgst : UInt8*, dlen : Int32, sig : UInt8*, siglen : Int32, dsa : DSA) : Int32
  fun i2d_dsapublickey = i2d_DSAPublicKey(dsa : DSA, pp : UInt8**) : Int32
  fun d2i_dsapublickey = d2i_DSAPublicKey(dsa : DSA*, pp : UInt8**, length : Int64) : Int32

  alias X509_NAME = Void*

  fun x509_name_free = X509_NAME_free(name : X509_NAME)
  fun x509_name_dup = X509_NAME_dup(name : X509_NAME) : X509_NAME
  fun x509_name_print_ex = X509_NAME_print_ex(bio : BIO, name : X509_NAME, indent : Int32, flags : UInt64) : Int32

  alias X509_STORE_CTX = Void*
  alias X509 = Void*

  fun x509_store_ctx_get_error = X509_STORE_CTX_get_error(store : X509_STORE_CTX) : Int32
  fun x509_store_ctx_get_current_cert = X509_STORE_CTX_get_current_cert(store : X509_STORE_CTX) : X509

  fun x509_new = X509_new : X509
  fun x509_free = X509_free(x509 : X509)
  fun pem_read_bio_x509 = PEM_read_bio_X509(bio : BIO, x509 : X509*, cb : PasswordCallback, user_data : Void*) : X509
  fun pem_write_bio_x509 = PEM_write_bio_X509(bio : BIO, x509 : X509) : Int32
  fun x509_get_pubkey = X509_get_pubkey(x509 : X509) : EVP_PKEY
  fun x509_get_subject_name = X509_get_subject_name(x509 : X509) : X509_NAME
  fun x509_digest = X509_digest(x509 : X509, type : EVP_MD, md : UInt8*, len : UInt32*) : Int32
  fun x509_set_version = X509_set_version(x509 : X509, version : Int64) : Int32
  fun x509_get_serialnumber = X509_get_serialNumber(x509 : X509) : ASN1_INTEGER
  fun x509_set_notbefore = X509_set_notBefore(x509 : X509, tm : ASN1_TIME) : Int32
  fun x509_set_notafter = X509_set_notAfter(x509 : X509, tm : ASN1_TIME) : Int32
  fun x509_set_pubkey = X509_set_pubkey(x509 : X509, pkey : EVP_PKEY) : Int32
  fun x509_verify = X509_verify(x509 : X509, pkey : EVP_PKEY) : Int32

  MBSTRING_FLAG = 0x1000
  MBSTRING_UTF8 = MBSTRING_FLAG

  fun x509_name_add_entry_by_txt = X509_NAME_add_entry_by_txt(name : X509_NAME, field : UInt8*, type : Int32, bytes : UInt8*, len : Int32,
                                                              loc : Int32, set : Int32) : Int32
  fun x509_set_issuer_name = X509_set_issuer_name(x509 : X509, name : X509_NAME) : Int32

  struct X509V3_CTX
    flags : Int32
    issuer_cert : Void*
    subject_cert : Void*
    subject_req : Void*
    crl : Void*
    db_meth : Void*
    db : Void*
  end

  alias X509_REQ = Void*
  alias X509_CRL = Void*
  alias X509_EXTENSION = Void*

  fun x509v3_set_ctx = X509V3_set_ctx(ctx : X509V3_CTX*, issuer : X509, subj : X509, req : X509_REQ,
                                      crl : X509_CRL, flags : Int32)
  fun x509v3_ext_conf_nid = X509V3_EXT_conf_nid(conf : Void*, ctx : X509V3_CTX*, ext_nid : Int32, value : UInt8*) : X509_EXTENSION
  fun x509_add_ext = X509_add_ext(x509 : X509, ex : X509_EXTENSION, loc : Int32) : Int32

  NID_ext_key_usage = 126
  NID_key_usage     =  83

  fun x509_extension_free = X509_EXTENSION_free(ex : X509_EXTENSION)
  fun x509_sign = X509_sign(x509 : X509, pkey : EVP_PKEY, md : EVP_MD) : Int32

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
