require "../bcrypt"
require "../subtle"

# Generate, read, and verify `Crypto::Bcrypt` password hashes.
#
# Use `.create` to hash a new plaintext password with a random salt,
# and `.new` to load and parse an existing hash string for verification via `#verify`.
#
# NOTE: To use `Password`, you must explicitly import it with `require "crypto/bcrypt/password"`
#
# ```
# require "crypto/bcrypt/password"
#
# # Hash a new password for storage
# password = Crypto::Bcrypt::Password.create("super secret", cost: 10)
# password.to_s # => "$2a$10$rI4xRiuAN2fyiKwynO6PPuorfuoM4L2PVv6hlnVJEmNLjqcibAfHq"
#
# # Verify candidates against the hash
# password.verify("wrong secret") # => false
# password.verify("super secret") # => true
# ```
#
# See `Crypto::Bcrypt` for hints to select the cost when generating hashes.
class Crypto::Bcrypt::Password
  private SUPPORTED_VERSIONS = ["2", "2a", "2b", "2y"]

  # Hashes a plaintext *password* using the bcrypt algorithm with a randomly generated salt.
  #
  # Returns a `Password` instance containing the generated hash, ready for storage or verification.
  #
  # ```
  # require "crypto/bcrypt/password"
  #
  # password = Crypto::Bcrypt::Password.create("super secret", cost: 10)
  # password.to_s # => "$2a$10$rI4xRiuAN2fyiKwynO6PPuorfuoM4L2PVv6hlnVJEmNLjqcibAfHq"
  # ```
  #
  # Raises `Crypto::Bcrypt::Error` if *cost* is not in `4..31` or *password* exceeds 71 bytes.
  def self.create(password : String, cost : Int32 = DEFAULT_COST) : self
    new(Bcrypt.hash_secret(password, cost).to_s)
  end

  getter version : String
  getter cost : Int32
  getter salt : String
  getter digest : String

  # Loads and parses an existing formatted bcrypt hash string (such as one retrieved from storage).
  #
  # NOTE: This method does **not** hash a plaintext password. To hash a new password,
  # use `.create`.
  #
  # ```
  # require "crypto/bcrypt/password"
  #
  # password = Crypto::Bcrypt::Password.new("$2a$10$X6rw/jDiLBuzHV./JjBNXe8/Po4wTL0fhdDNdAdjcKN/Fup8tGCya")
  # password.version # => "2a"
  # password.salt    # => "X6rw/jDiLBuzHV./JjBNXe"
  # password.digest  # => "8/Po4wTL0fhdDNdAdjcKN/Fup8tGCya"
  #
  # # Passing a plaintext password raises an error:
  # Crypto::Bcrypt::Password.new("my_password") # => raises Crypto::Bcrypt::Error (Invalid hash string)
  # ```
  #
  # Raises `Crypto::Bcrypt::Error` if *raw_hash* is not a valid modular crypt format hash string,
  # has an unsupported version, or contains an invalid cost, salt size, or digest size.
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

  # Verifies a plaintext *password* against the hash using constant-time comparison.
  #
  # Returns `true` if *password* matches the hash, `false` otherwise.
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

  # Returns the bcrypt hash, suitable for storage and use in `Crypto::Bcrypt::Password.new`.
  #
  # ```
  # require "crypto/bcrypt/password"
  #
  # password = Crypto::Bcrypt::Password.create("super secret")
  # password.to_s # => "$2a$11$zs8yeubYXMGGJmWyIYdFtO9aOrx44g5rarvixyBfl1klr3dZPG8Ma"
  # ```
  def to_s(io : IO) : Nil
    io << @raw_hash
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end
end
