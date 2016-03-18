require "secure_random"
require "./subtle"

# Pure Crystal implementation of the Bcrypt algorithm by Niels Provos and David
# Mazières, as [presented at USENIX in
# 1999](https://www.usenix.org/legacy/events/usenix99/provos/provos_html/index.html).
#
# Refer to `Crypto::Bcrypt::Password` for a higher level interface.
#
# About the Cost
#
# Bcrypt, like the PBKDF2 or scrypt ciphers, are designed to be slow, so
# generating rainbow tables or cracking passwords is nearly impossible. Yet,
# computers are always getting faster and faster, so the actual cost must be
# incremented every once in a while.
# Always use the maximum cost that is tolerable, performance wise, for your
# application. Be sure to test and select this based on your server, not your
# home computer.
#
# This implementation of Bcrypt is currently 50% slower than pure C solutions,
# so keep this in mind when selecting your cost. It may be wise to test with
# Ruby's bcrypt gem which is a binding to OpenBSD's implementation.
#
# Last but not least: beware of denial of services! Always protect your
# application using an external strategy (eg: rate limiting), otherwise
# endpoints that verifies bcrypt hashes will be an easy target.
class Crypto::Bcrypt
  class Error < Exception
  end

  DEFAULT_COST   = 11
  COST_RANGE     = 4..31
  PASSWORD_RANGE = 1..51
  SALT_SIZE      = 16

  # :nodoc:
  BLOWFISH_ROUNDS = 16

  # :nodoc:
  DIGEST_SIZE = 31

  # bcrypt IV: "OrpheanBeholderScryDoubt"
  # :nodoc:
  CIPHER_TEXT = Int32[
    0x4f727068, 0x65616e42, 0x65686f6c,
    0x64657253, 0x63727944, 0x6f756274,
  ]

  def self.hash_secret(password, cost = DEFAULT_COST)
    passwordb = password.to_unsafe.to_slice(password.bytesize + 1) # include leading 0
    saltb = SecureRandom.random_bytes(SALT_SIZE)
    new(passwordb, saltb, cost).to_s
  end

  def self.new(password : String, salt : String, cost = DEFAULT_COST)
    passwordb = password.to_unsafe.to_slice(password.bytesize + 1) # include leading 0
    saltb = Base64.decode(salt, SALT_SIZE)
    new(passwordb, saltb, cost)
  end

  getter password : Slice(UInt8)
  getter salt : Slice(UInt8)
  getter cost : Int32

  def initialize(@password, @salt, @cost = DEFAULT_COST)
    raise Error.new("Invalid cost") unless COST_RANGE.includes?(cost)
    raise Error.new("Invalid salt size") unless salt.size == SALT_SIZE
    raise Error.new("Invalid password size") unless PASSWORD_RANGE.includes?(password.size)
  end

  @digest : Slice(UInt8)?

  def digest
    @digest ||= hash_password
  end

  @hash : String?

  def to_s
    @hash ||= begin
      salt64 = Base64.encode(salt, salt.size)
      digest64 = Base64.encode(digest, digest.size - 1)
      "$2a$%02d$%s%s" % {cost, salt64, digest64}
    end
  end

  def to_s(io)
    io << to_s
  end

  def inspect(io)
    to_s(io)
  end

  delegate :to_slice, :to_s

  private def hash_password
    blowfish = Blowfish.new(BLOWFISH_ROUNDS)
    blowfish.enhance_key_schedule(salt, password, cost)

    cdata = CIPHER_TEXT.dup
    size = cdata.size

    0.step(4, 2) do |i|
      64.times do
        l, r = blowfish.encrypt_pair(cdata[i], cdata[i + 1])
        cdata[i], cdata[i + 1] = l, r
      end
    end

    ret = Slice(UInt8).new(size * 4)
    j = -1

    size.times do |i|
      ret[j += 1] = (cdata[i] >> 24).to_u8
      ret[j += 1] = (cdata[i] >> 16).to_u8
      ret[j += 1] = (cdata[i] >> 8).to_u8
      ret[j += 1] = cdata[i].to_u8
    end

    ret
  end
end

require "./bcrypt/*"
