require "./lib_crypto"
require "./digest/*"
class OpenSSL::Digest
  def self.digest(algorithm)
    case algorithm
    when :dss       then DSS.new
    when :dss1      then DSS1.new
    when :md4       then MD4.new
    when :md5       then MD5.new
    when :mdc2      then MDC2.new
    when :ripemd160 then RIPEMD160.new
    when :sha       then SHA.new
    when :sha1      then SHA1.new
    when :sha224    then SHA224.new
    when :sha256    then SHA256.new
    when :sha384    then SHA384.new
    when :sha512    then SHA512.new
    else                 raise "Unsupported digest algorithm: #{algorithm}"
    end
  end
end
