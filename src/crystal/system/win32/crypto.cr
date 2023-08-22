require "c/wincrypt"
require "openssl"

module Crystal::System::Crypto
  private ServerAuthOID = "1.3.6.1.5.5.7.3.1"

  # heavily based on cURL's code for importing system certificates on Windows:
  # https://github.com/curl/curl/blob/2f17a9b654121dd1ecf4fc043c6d08a9da3522db/lib/vtls/openssl.c#L3015-L3157
  private def self.each_system_certificate(store_name : String, &)
    now = ::Time.utc

    return unless cert_store = LibC.CertOpenSystemStoreW(nil, System.to_wstr(store_name))

    eku = Pointer(LibC::CERT_USAGE).null
    cert_context = Pointer(LibC::CERT_CONTEXT).null
    while cert_context = LibC.CertEnumCertificatesInStore(cert_store, cert_context)
      next unless cert_context.value.dwCertEncodingType == LibC::X509_ASN_ENCODING

      next if cert_context.value.pbCertEncoded.nil?

      not_before = Crystal::System::Time.from_filetime(cert_context.value.pCertInfo.value.notBefore)
      not_after = Crystal::System::Time.from_filetime(cert_context.value.pCertInfo.value.notAfter)
      next unless not_before <= now <= not_after

      # look for the serverAuth OID if extended key usage exists
      if LibC.CertGetEnhancedKeyUsage(cert_context, 0, nil, out eku_size) != 0
        eku = eku.as(UInt8*).realloc(eku_size).as(LibC::CERT_USAGE*)
        next unless LibC.CertGetEnhancedKeyUsage(cert_context, 0, eku, pointerof(eku_size)) != 0
        next unless (0...eku.value.cUsageIdentifier).any? do |i|
                      LibC.strcmp(eku.value.rgpszUsageIdentifier[i], ServerAuthOID) == 0
                    end
      end

      encoded = Slice.new(cert_context.value.pbCertEncoded, cert_context.value.cbCertEncoded)
      until encoded.empty?
        cert, encoded = OpenSSL::X509::Certificate.from_der?(encoded)
        break unless cert
        yield cert
      end
    end
  ensure
    LibC.CertCloseStore(cert_store, 0) if cert_store
  end

  private class_getter system_root_certificates : Array(OpenSSL::X509::Certificate) do
    certs = [] of OpenSSL::X509::Certificate
    each_system_certificate("ROOT") { |cert| certs << cert }
    certs
  end

  def self.populate_system_root_certificates(ssl_context)
    cert_store = LibSSL.ssl_ctx_get_cert_store(ssl_context)
    system_root_certificates.each do |cert|
      LibCrypto.x509_store_add_cert(cert_store, cert)
    end
  end
end
