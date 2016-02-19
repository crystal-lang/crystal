require "../openssl"
require "../asn1/time"

class OpenSSL::X509::Generator
  enum KeyUsage
    DigitalSignature
    NonRepudiation
    KeyEncipherment
    DataEncipherment
    KeyAgreement
    KeyCertSign
    CRLSign
    EncipherOnly
    DecipherOnly
  end

  enum ExtKeyUsage
    ServerAuth
    ClientAuth
    CodeSigning
    EmailProtection
    TimeStamping
    MsCodeInd
    MsCodeCom
    MsCtlSign
    MsSgc
    MsEfs
    NsSgc
  end

  def self.generate
    g = new
    yield g
    g.generate
  end

  def initialize(@bitlength = 1024, @valid_period = 365, @cn = "localhost",
                 @digest = OpenSSL::Digest.new("SHA256"), @usage = [] of KeyUsage,
                 @ext_usage = [] of ExtKeyUsage)
  end

  property bitlength
  property valid_period
  property cn
  property digest
  property usage
  property ext_usage

  def generate
    pkey = PKey::RSA.new(bitlength)
    certificate = Certificate.new
    sign(certificate, pkey)
    {certificate, pkey}
  end

  private def sign(certificate, pkey)
    LibCrypto.x509_set_version(certificate, 2_i64)
    sn = LibCrypto.x509_get_serialnumber(certificate)
    LibCrypto.asn1_integer_set(sn, random_serial)

    not_before = ASN1::Time.days_from_now(0)
    not_after = ASN1::Time.days_from_now(valid_period)

    LibCrypto.x509_set_notbefore(certificate, not_before)
    LibCrypto.x509_set_notafter(certificate, not_after)

    LibCrypto.x509_set_pubkey(certificate, pkey)

    name = LibCrypto.x509_get_subject_name(certificate)
    add_name(name, "CN", cn)
    LibCrypto.x509_set_issuer_name(certificate, name)

    unless usage.empty?
      value = usage.map { |v| v.to_s.gsub(/^\w/) { |s| s[0].downcase } }.join(",")
      add_extension(certificate, LibCrypto::NID_key_usage, value)
    end
    unless ext_usage.empty?
      value = ext_usage.map { |v| v.to_s.gsub(/^\w/) { |s| s[0].downcase } }.join(",")
      add_extension(certificate, LibCrypto::NID_ext_key_usage, value)
    end
    if LibCrypto.x509_sign(certificate, pkey, digest.to_unsafe_md) == 0
      raise OpenSSL::Error.new
    end
  end

  private def add_name(name, key, value)
    LibCrypto.x509_name_add_entry_by_txt(name, key, LibCrypto::MBSTRING_UTF8, value, value.bytesize, -1, 0)
  end

  private def add_extension(certificate, extension, value)
    ctx = LibCrypto::X509V3_CTX.new
    LibCrypto.x509v3_set_ctx(pointerof(ctx), certificate, certificate, nil, nil, 0)
    ext = LibCrypto.x509v3_ext_conf_nid(nil, pointerof(ctx), extension, value)
    if LibCrypto.x509_add_ext(certificate, ext, -1) == 0
      LibCrypto.x509_extension_free(ext)
      raise OpenSSL::Error.new
    end
  end

  private def random_serial
    long = uninitialized Int64
    ptr = pointerof(long) as Int32*
    ptr[0] = rand(UInt32::MAX)
    ptr[1] = rand(UInt32::MAX)
    long
  end
end
