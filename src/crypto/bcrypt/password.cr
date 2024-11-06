require "../bcrypt"
require "../subtle"

# Generate, read and verify `Crypto::Bcrypt` hashes.
#
# NOTE: To use `Password`, you must explicitly import it with `require "crypto/bcrypt/password"`
#
# ```
# require "crypto/bcrypt/password"
#
# password = Crypto::Bcrypt::Password.create("super secret", cost: 10)
# # => $2a$10$rI4xRiuAN2fyiKwynO6PPuorfuoM4L2PVv6hlnVJEmNLjqcibAfHq
#
# password.verify("wrong secret") # => false
# password.verify("super secret") # => true
# ```
#
# See `Crypto::Bcrypt` for hints to select the cost when generating hashes.
class Crypto::Bcrypt::Password
  private SUPPORTED_VERSIONS = ["2", "2a", "2b", "2y"]

  # Hashes a password.
  #
  # ```
  # require "crypto/bcrypt/password"
  #
  # password = Crypto::Bcrypt::Password.create("super secret", cost: 10)
  # # => $2a$10$rI4xRiuAN2fyiKwynO6PPuorfuoM4L2PVv6hlnVJEmNLjqcibAfHq
  # ```
  def self.create(password, cost = DEFAULT_COST) : self
    new(Bcrypt.hash_secret(password, cost).to_s)
  end

  getter version : String
  getter cost : Int32
  getter salt : String
  getter digest : String

  # Loads a bcrypt hash.
  #
  # ```
  # require "crypto/bcrypt/password"
  #
  # password = Crypto::Bcrypt::Password.new("$2a$10$X6rw/jDiLBuzHV./JjBNXe8/Po4wTL0fhdDNdAdjcKN/Fup8tGCya")
  # password.version # => "2a"
  # password.salt    # => "X6rw/jDiLBuzHV./JjBNXe"
  # password.digest  # => "8/Po4wTL0fhdDNdAdjcKN/Fup8tGCya"
  # ```
  def initialize(@raw_hash : String)
    parts = @raw_hash.split('$')
    raise Error.new("Invalid hash string") unless parts.size == 4
    raise Error.new("Invalid hash version") unless SUPPORTED_VERSIONS.includes?(parts[1])

    @version = parts[1]
    @cost = parts[2].to_i
    @salt = parts[3][0..21]
    @digest = parts[3][22..-1]

    raise Error.new("Invalid cost") unless COST_RANGE.includes?(cost)
    raise Error.new("Invalid salt size") unless salt.size == 22
    raise Error.new("Invalid digest size") unless digest.size == 31
  end

  # Verifies a password against the hash.
  #
  # ```
  # require "crypto/bcrypt/password"
  #
  # password = Crypto::Bcrypt::Password.create("super secret")
  # password.verify("wrong secret") # => false
  # password.verify("super secret") # => true
  # ```
  def verify(password : String) : Bool
    hashed_password = Bcrypt.new(password, salt, cost)
    hashed_password_digest = Base64.encode(hashed_password.digest, hashed_password.digest.size - 1)
    Crypto::Subtle.constant_time_compare(@digest, hashed_password_digest)
  end

  def to_s(io : IO) : Nil
    io << @raw_hash
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end
end
