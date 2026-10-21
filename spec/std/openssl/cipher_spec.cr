require "../spec_helper"
require "openssl/cipher"

describe OpenSSL::Cipher do
  it "encrypts/decrypts" do
    cipher = "aes-128-cbc"
    c1 = OpenSSL::Cipher.new(cipher)
    c2 = OpenSSL::Cipher.new(cipher)
    key = "\0" * 16
    iv = "\0" * 16
    data = "DATA" * 5
    ciphertext = File.read(datapath("cipher_spec.ciphertext"))

    c1.name.should eq(c2.name)

    c1.encrypt
    c2.encrypt
    c1.key = c2.key = key
    c1.iv = c2.iv = iv

    s1 = IO::Memory.new
    s2 = IO::Memory.new
    s1.write(c1.update("DATA"))
    s1.write(c1.update("DATA" * 4))
    s1.write(c1.final)
    s2.write(c2.update(data))
    s2.write(c2.final)

    s1.to_slice.should eq(ciphertext.to_slice)
    s1.to_slice.should eq(s2.to_slice)

    c1.decrypt
    c2.decrypt
    c1.key = c2.key = key
    c1.iv = c2.iv = iv

    s3 = IO::Memory.new
    s4 = IO::Memory.new
    s3.write(c1.update(s1.to_slice))
    s3.write(c1.final)

    s4.write(c2.update(s2.to_slice))
    s4.write(c2.final)
    s3.to_s.should eq(data)
    s3.to_slice.should eq(s4.to_slice)
  end

  it "authenticated?" do
    begin
      cipher = OpenSSL::Cipher.new("aes-128-gcm")
      cipher.authenticated?.should be_true
    rescue ArgumentError
      # This system doesn't support GCM ciphers
      # Silently skip, as this method will never return true
      # Remove when macOS platforms target >= v10.13
    end

    cipher = OpenSSL::Cipher.new("aes-128-cbc")
    cipher.authenticated?.should be_false
  end

  it "encrypts/decrypts with GCM authentication tag" do
    key = Random::Secure.random_bytes(32)
    iv = Random::Secure.random_bytes(12)
    plaintext = "Hello, GCM!"

    enc = OpenSSL::Cipher.new("aes-256-gcm")
    enc.encrypt
    enc.key = key
    enc.iv = iv
    ciphertext = enc.update(plaintext)
    ciphertext += enc.final
    tag = enc.gcm_tag

    dec = OpenSSL::Cipher.new("aes-256-gcm")
    dec.decrypt
    dec.key = key
    dec.iv = iv
    dec.gcm_tag = tag
    result = dec.update(ciphertext)
    result += dec.final
    String.new(result).should eq(plaintext)
  end

  describe "#auth_data=" do
    # Test case 4 of "The Galois/Counter Mode of Operation (GCM)" by McGrew and Viega
    key = "feffe9928665731c6d6a8f9467308308".hexbytes
    iv = "cafebabefacedbaddecaf888".hexbytes
    plaintext = "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39".hexbytes
    auth_data = "feedfacedeadbeeffeedfacedeadbeefabaddad2".hexbytes
    ciphertext = "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091".hexbytes
    tag = "5bc94fbc3221a5db94fae95ae7121a47".hexbytes

    it "encrypts with additional authenticated data" do
      cipher = OpenSSL::Cipher.new("aes-128-gcm")
      cipher.encrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_data = auth_data
      result = cipher.update(plaintext) + cipher.final
      result.should eq(ciphertext)
      cipher.gcm_tag.should eq(tag)
    end

    it "decrypts with additional authenticated data" do
      cipher = OpenSSL::Cipher.new("aes-128-gcm")
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_data = auth_data
      cipher.gcm_tag = tag
      result = cipher.update(ciphertext) + cipher.final
      result.should eq(plaintext)
    end

    it "fails to decrypt with different additional authenticated data" do
      cipher = OpenSSL::Cipher.new("aes-128-gcm")
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_data = "other header"
      cipher.gcm_tag = tag
      cipher.update(ciphertext)
      expect_raises(OpenSSL::Cipher::Error, "EVP_CipherFinal_ex") do
        cipher.final
      end
    end

    it "accepts a string and empty data" do
      random_key = Random::Secure.random_bytes(32)
      random_iv = Random::Secure.random_bytes(12)

      encrypt = OpenSSL::Cipher.new("aes-256-gcm")
      encrypt.encrypt
      encrypt.key = random_key
      encrypt.iv = random_iv
      encrypt.auth_data = ""
      encrypt.auth_data = "header"
      encrypted = encrypt.update("Hello, GCM!") + encrypt.final

      decrypt = OpenSSL::Cipher.new("aes-256-gcm")
      decrypt.decrypt
      decrypt.key = random_key
      decrypt.iv = random_iv
      decrypt.auth_data = "header"
      decrypt.gcm_tag = encrypt.gcm_tag
      result = decrypt.update(encrypted) + decrypt.final
      String.new(result).should eq("Hello, GCM!")
    end

    it "appends data set several times" do
      cipher = OpenSSL::Cipher.new("aes-128-gcm")
      cipher.encrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_data = auth_data[0, 7]
      cipher.auth_data = auth_data[7..]
      result = cipher.update(plaintext) + cipher.final
      result.should eq(ciphertext)
      cipher.gcm_tag.should eq(tag)
    end

    it "raises after data was processed" do
      cipher = OpenSSL::Cipher.new("aes-128-gcm")
      cipher.encrypt
      cipher.key = key
      cipher.iv = iv
      cipher.update(plaintext)
      expect_raises(OpenSSL::Cipher::Error, "EVP_CipherUpdate") do
        cipher.auth_data = auth_data
      end
    end

    it "raises for a cipher that isn't authenticated" do
      cipher = OpenSSL::Cipher.new("aes-128-cbc")
      cipher.encrypt
      expect_raises(OpenSSL::Cipher::Error, "Cipher is not authenticated") do
        cipher.auth_data = auth_data
      end
    end
  end
end
