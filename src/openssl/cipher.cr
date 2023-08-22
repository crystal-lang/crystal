require "random/secure"
require "openssl"

# A class which can be used to encrypt and decrypt data using a specified cipher.
#
# ```
# require "random/secure"
#
# key = Random::Secure.random_bytes(64) # You can also use OpenSSL::Cipher#random_key to do this same thing
# iv = Random::Secure.random_bytes(32)  # You can also use OpenSSL::Cipher#random_iv to do this same thing
#
# def encrypt(data)
#   cipher = OpenSSL::Cipher.new("aes-256-cbc")
#   cipher.encrypt
#   cipher.key = key
#   cipher.iv = iv
#
#   io = IO::Memory.new
#   io.write(cipher.update(data))
#   io.write(cipher.final)
#   io.rewind
#
#   io.to_slice
# end
#
# def decrypt(data)
#   cipher = OpenSSL::Cipher.new("aes-256-cbc")
#   cipher.decrypt
#   cipher.key = key
#   cipher.iv = iv
#
#   io = IO::Memory.new
#   io.write(cipher.update(data))
#   io.write(cipher.final)
#   io.rewind
#
#   io.gets_to_end
# end
# ```
class OpenSSL::Cipher
  class Error < OpenSSL::Error
  end

  def initialize(name)
    cipher = LibCrypto.evp_get_cipherbyname name
    raise ArgumentError.new "Unsupported cipher algorithm #{name.inspect}" unless cipher

    @ctx = LibCrypto.evp_cipher_ctx_new
    # The EVP which has EVP_CIPH_RAND_KEY flag (such as DES3) allows
    # uninitialized key, but other EVPs (such as AES) does not allow it.
    # Calling EVP_CipherUpdate() without initializing key causes SEGV so
    # we set the data filled with "\0" as the key by default.
    cipherinit cipher: cipher, key: "\0" * LibCrypto::EVP_MAX_KEY_LENGTH
  end

  # Sets this cipher to encryption mode.
  def encrypt : Nil
    cipherinit enc: 1
  end

  # Sets this cipher to decryption mode.
  def decrypt : Nil
    cipherinit enc: 0
  end

  def key=(key)
    raise ArgumentError.new "Key length too short: wanted #{key_len}, got #{key.bytesize}" if key.bytesize < key_len
    cipherinit key: key
    key
  end

  def iv=(iv)
    raise ArgumentError.new "IV length too short: wanted #{iv_len}, got #{iv.bytesize}" if iv.bytesize < iv_len
    cipherinit iv: iv
    iv
  end

  # Sets the key using `Random::Secure`.
  def random_key
    key = Random::Secure.random_bytes key_len
    self.key = key
  end

  # Sets the iv using `Random::Secure`.
  def random_iv
    iv = Random::Secure.random_bytes iv_len
    self.iv = iv
  end

  # Resets the encrypt/decrypt mode.
  def reset
    cipherinit
  end

  # Add the data to be encrypted or decrypted to this cipher's buffer.
  def update(data)
    slice = data.to_slice
    buffer_length = slice.size + block_size
    buffer = Bytes.new(buffer_length)
    if LibCrypto.evp_cipherupdate(@ctx, buffer, pointerof(buffer_length), slice, slice.size) != 1
      raise Error.new "EVP_CipherUpdate"
    end

    buffer[0, buffer_length]
  end

  # Outputs the decrypted or encrypted buffer.
  def final : Bytes
    buffer_length = block_size
    buffer = Bytes.new(buffer_length)

    if LibCrypto.evp_cipherfinal_ex(@ctx, buffer, pointerof(buffer_length)) != 1
      raise Error.new "EVP_CipherFinal_ex"
    end

    buffer[0, buffer_length]
  end

  def padding=(pad : Bool)
    if LibCrypto.evp_cipher_ctx_set_padding(@ctx, pad ? 1 : 0) != 1
      raise Error.new "EVP_CIPHER_CTX_set_padding"
    end

    pad
  end

  def name : String
    nid = LibCrypto.evp_cipher_nid cipher
    sn = LibCrypto.obj_nid2sn nid
    String.new sn
  end

  def block_size : Int32
    LibCrypto.evp_cipher_block_size cipher
  end

  # How many bytes the key should be.
  def key_len : Int32
    LibCrypto.evp_cipher_key_length cipher
  end

  # How many bytes the iv should be.
  def iv_len : Int32
    LibCrypto.evp_cipher_iv_length cipher
  end

  def finalize
    LibCrypto.evp_cipher_ctx_free(@ctx) if @ctx
    @ctx = typeof(@ctx).null
  end

  def authenticated? : Bool
    LibCrypto.evp_cipher_flags(cipher).includes?(LibCrypto::CipherFlags::EVP_CIPH_FLAG_AEAD_CIPHER)
  end

  private def cipherinit(cipher = nil, engine = nil, key = nil, iv = nil, enc = -1)
    if LibCrypto.evp_cipherinit_ex(@ctx, cipher, engine, key, iv, enc) != 1
      raise Error.new "EVP_CipherInit_ex"
    end

    nil
  end

  private def cipher
    LibCrypto.evp_cipher_ctx_cipher @ctx
  end
end
