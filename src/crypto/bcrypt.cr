require "secure_random"
require "./blowfish"
require "./subtle"
require "./bcrypt/base64"

module Crypto::Bcrypt
  extend self

  MIN_COST = 4
  MAX_COST = 63
  DEFAULT_COST = 10
  ENCODED_SALT_SIZE = 22
  MIN_HASH_SIZE = 59
  MAJOR_VERSION = "2"
  MINOR_VERSION = "a"

  record Info, major, minor, cost, salt, hash

  def digest(password, cost = DEFAULT_COST)
    p = generate(password, cost)

    build_hash(p)
  end

  def verify(password, hashedPassword)
    p = generate_from_hash(hashedPassword)
    other_p_hash = bcrypt(password, p.cost, p.salt)
    other_p = Info.new p.major, p.minor, p.cost, p.salt, other_p_hash

    if Subtle.constant_time_compare(build_hash(p).to_slice, build_hash(other_p).to_slice) == 1
      return true
    end

    false
  end

  private def generate(password, cost)
    check_valid_cost cost

    cost = cost.to_s
    unencodedSalt = SecureRandom.hex(8)
    salt = Bcrypt::Base64.encode(unencodedSalt)
    hash = bcrypt(password, cost, salt)

    Info.new MAJOR_VERSION, MINOR_VERSION, cost, salt, hash
  end

  private def generate_from_hash(password)
    if password.length < MIN_HASH_SIZE
      raise ArgumentError.new "Invalid hashedSecret size: hashedSecret too short to be a bcrypted password"
    end

    major, minor = decode_version(password)
    cost = decode_cost(password).to_s
    salt = password[7..(ENCODED_SALT_SIZE+6)]
    hash = password[(ENCODED_SALT_SIZE+7)..-1]

    Info.new major, minor, cost, salt, hash
  end

  private def bcrypt(password, cost, salt)
    bf = setup(password, cost, salt)
    # OrpheanBeholderScryDoubt
    slice :: Int64[24]
    slice[ 0] = 0x4f_i64
    slice[ 1] = 0x72_i64
    slice[ 2] = 0x70_i64
    slice[ 3] = 0x68_i64
    slice[ 4] = 0x65_i64
    slice[ 5] = 0x61_i64
    slice[ 6] = 0x6e_i64
    slice[ 7] = 0x42_i64
    slice[ 8] = 0x65_i64
    slice[ 9] = 0x68_i64
    slice[10] = 0x6f_i64
    slice[11] = 0x6c_i64
    slice[12] = 0x64_i64
    slice[13] = 0x65_i64
    slice[14] = 0x72_i64
    slice[15] = 0x53_i64
    slice[16] = 0x63_i64
    slice[17] = 0x72_i64
    slice[18] = 0x79_i64
    slice[19] = 0x44_i64
    slice[20] = 0x6f_i64
    slice[21] = 0x75_i64
    slice[22] = 0x62_i64
    slice[23] = 0x74_i64

    0.step(23, 2) do |i|
      0.upto(63) do |j|
        l, r = bf.encrypt_pair(slice[i], slice[i+1])
        slice[i] = l
        slice[i+1] = r
      end
    end

    Crypto::Bcrypt::Base64.encode(slice)
  end

  private def setup(key, cost, salt)
    sl = Crypto::Bcrypt::Base64.decode(salt)
    bf = Blowfish.new
    bf.salted_expand_key(sl, key)

    1.upto(1_u64 << cost.to_i) do |i|
      bf.expand_key(key)
      bf.expand_key(salt)
    end

    bf
  end

  private def build_hash(password)
    String.build do |io|
      io << "$"
      io << password.major
      io << password.minor
      io << "$"
      io << "%02d" % password.cost
      io << "$"
      io << password.salt
      io << password.hash
    end
  end

  private def decode_version(password)
    if password[0] != '$'
      raise ArgumentError.new "Invalid hash prefix"
    end

    if password[1] != MAJOR_VERSION[0]
      raise ArgumentError.new "Invalid hash version"
    end

    minor = ""
    minor = password[2] if password[2] != '$'

    {password[1].to_s, minor.to_s}
  end

  private def decode_cost(password)
    cost = password[4..5].to_i
    check_valid_cost cost
    cost
  end

  private def check_valid_cost(cost)
    unless MIN_COST <= cost <= MAX_COST
      raise ArgumentError.new "Invalid cost size: cost #{cost} is outside allowed range (#{MIN_COST}, #{MAX_COST})"
    end
  end
end
