require "../openssl"

class OpenSSL::ASN1::Time
  def initialize(@handle : LibCrypto::ASN1_TIME)
    raise OpenSSL::Error.new "Invalid handle" unless @handle
  end

  def initialize(period)
    initialize LibCrypto.x509_gmtime_adj(nil, period.to_i64)
  end

  def self.days_from_now(days)
    new(days * 60 * 60 * 24)
  end

  def finalize
    LibCrypto.asn1_time_free(self)
  end

  def to_unsafe
    @handle
  end
end
