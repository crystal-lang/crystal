require "secure_random"
require "./blowfish"
require "./subtle"
require "./base64"

module Crypto::Bcrypt
  extend self

  MIN_COST = 4
  MAX_COST = 31
  DEFAULT_COST = 10
  ENCODED_SALT_SIZE = 22
  MIN_HASH_SIZE = 59
  MAJOR_VERSION = '2'
  MINOR_VERSION = 'a'

  def digest(password, cost = DEFAULT_COST)
    p = generate(password, cost)

    build_hash(p)
  end

  def verify(password, hashedPassword)
    p = generate_from_hash(hashedPassword)

    otherP = {"major" => p["major"], "minor" => p["minor"], "cost" => p["cost"], "salt" => p["salt"]}
    otherP["hash"] = bcrypt(password, p["cost"], p["salt"])

    if Subtle.constant_time_compare(build_hash(p).to_slice, build_hash(otherP).to_slice) == 1
      return true
    end

    false
  end

  private def generate(password, cost)
    if cost < MIN_COST || cost > MAX_COST
      raise ArgumentError.new "Invalid cost size: cost #{cost} is outside allowed range (#{MIN_COST}, #{MAX_COST})"
    end

    p = {} of String => String
    p["major"] = MAJOR_VERSION.to_s
    p["minor"] = MINOR_VERSION.to_s
    p["cost"] = cost.to_s

    unencodedSalt = SecureRandom.hex(8)
    p["salt"] = Bcrypt::Base64.encode64(unencodedSalt)
    p["hash"] = bcrypt(password, p["cost"], p["salt"])
    p
  end

  private def generate_from_hash(password)
    if password.length < MIN_HASH_SIZE
      raise ArgumentError.new "Invalid hashedSecret size: hashedSecret too short to be a bcrypted password"
    end

    p = {} of String => String
    p["major"], p["minor"] = decode_version(password)
    p["cost"] = decode_cost(password).to_s
    p["salt"] = password[7..(ENCODED_SALT_SIZE+6)]
    p["hash"] = password[(ENCODED_SALT_SIZE+7)..-1]
    p
  end

  private def bcrypt(password, cost, salt)
    bf = setup(password, cost, salt)
    # OrpheanBeholderScryDoubt
    cipherData = [
      0x4f_i64, 0x72_i64, 0x70_i64, 0x68_i64,
      0x65_i64, 0x61_i64, 0x6e_i64, 0x42_i64,
      0x65_i64, 0x68_i64, 0x6f_i64, 0x6c_i64,
      0x64_i64, 0x65_i64, 0x72_i64, 0x53_i64,
      0x63_i64, 0x72_i64, 0x79_i64, 0x44_i64,
      0x6f_i64, 0x75_i64, 0x62_i64, 0x74_i64
    ]
    slice = Slice.new(cipherData.length) { |i| cipherData[i] }

    0.step(23, 2) do |i|
      0.upto(63) do |j|
        l, r = bf.encrypt_pair(slice[i], slice[i+1])
        slice[i] = l
        slice[i+1] = r
      end
    end

    Bcrypt::Base64.encode64(slice)
  end

  private def setup(key, cost, salt)
    sl = Bcrypt::Base64.decode64(salt)
    bf = Blowfish.new
    bf.salted_expand_key(sl, key)

    1.upto(1 << cost.to_i) do |i|
      bf.expand_key(key)
      bf.expand_key(salt)
    end

    bf
  end

  private def build_hash(password)
    String.build do |io|
      io << "$"
      io << password["major"]
      io << password["minor"]
      io << "$"
      io << "%02d" % password["cost"]
      io << "$"
      io << password["salt"]
      io << password["hash"]
    end
  end

  private def decode_version(password)
    if password[0] != '$'
      raise ArgumentError.new "Invalid hash prefix"
    end

    if password[1] != MAJOR_VERSION
      raise ArgumentError.new "Invalid hash version"
    end

    minor = ""
    minor = password[2] if password[2] != '$'

    {password[1].to_s, minor.to_s}
  end

  private def decode_cost(password)
    cost = password[4..5].to_i

    if cost < MIN_COST || cost > MAX_COST
      raise ArgumentError.new "Invalid cost size: cost #{cost} is outside allowed range (#{MIN_COST}, #{MAX_COST})"
    end

    cost
  end
end