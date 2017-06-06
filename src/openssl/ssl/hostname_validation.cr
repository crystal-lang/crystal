require "socket"
require "openssl"

# :nodoc:
module OpenSSL::SSL::HostnameValidation
  enum Result
    Error
    MalformedCertificate
    MatchFound
    MatchNotFound
    NoSANPresent
  end

  # Matches hostname against Subject Alternate Name (SAN) entries of the
  # certificate.
  #
  # The Common Name (CN) entry will only be used if no SAN entries are present
  # in the certificate, as per
  # [RFC 6125, Section 6.4.4](https://tools.ietf.org/html/rfc6125#section-6.4.4).
  def self.validate_hostname(hostname : String, server_cert : LibCrypto::X509)
    return Result::Error if server_cert.null?
    result = matches_subject_alternative_name(hostname, server_cert)
    result = matches_common_name(hostname, server_cert) if result.no_san_present?
    result
  end

  # Matches hostname against Subject Alternate Name (SAN) entries of certificate.
  #
  # Adapted from https://wiki.openssl.org/index.php/Hostname_validation
  def self.matches_subject_alternative_name(hostname, server_cert : LibCrypto::X509)
    san_names = LibCrypto.x509_get_ext_d2i(server_cert, LibCrypto::NID_subject_alt_name, nil, nil)
    return Result::NoSANPresent if san_names.null?

    LibCrypto.sk_num(san_names).times do |i|
      current_name = LibCrypto.sk_value(san_names, i).as(LibCrypto::GENERAL_NAME*).value

      case current_name.type
      when LibCrypto::GEN_DNS
        dns_name = LibCrypto.asn1_string_data(current_name.value)
        dns_name_len = LibCrypto.asn1_string_length(current_name.value)
        return Result::MalformedCertificate if dns_name_len != LibC.strlen(dns_name)

        pattern = String.new(dns_name, dns_name_len)
        return Result::MatchFound if matches_hostname?(pattern, hostname)
      when LibCrypto::GEN_IPADD
        data = LibCrypto.asn1_string_data(current_name.value)
        len = LibCrypto.asn1_string_length(current_name.value)

        case len
        when 4
          addr = uninitialized LibC::InAddr
          if LibC.inet_pton(LibC::AF_INET, hostname, pointerof(addr).as(Void*)) > 0
            return Result::MatchFound if addr == data.as(LibC::InAddr*).value
          end
        when 16
          addr6 = uninitialized LibC::In6Addr
          if LibC.inet_pton(LibC::AF_INET6, hostname, pointerof(addr6).as(Void*)) > 0
            return Result::MatchFound if addr6.unsafe_as(StaticArray(UInt32, 4)) == data.as(StaticArray(UInt32, 4)*).value
          end
        end
      end
    end

    Result::MatchNotFound
  ensure
    LibCrypto.sk_pop_free(san_names, ->(ptr : Void*) {
      LibCrypto.sk_free(ptr)
    })
  end

  # Matches hostname from Common Name (CN) entry of certificate. Should only be
  # called if no SAN entries could be found in certificate.
  #
  # Adapted from https://wiki.openssl.org/index.php/Hostname_validation
  def self.matches_common_name(hostname, server_cert : LibCrypto::X509)
    subject = LibCrypto.x509_get_subject_name(server_cert)

    index = LibCrypto.x509_name_get_index_by_nid(subject, LibCrypto::NID_commonName, -1)
    return Result::Error if index < 0

    name_entry = LibCrypto.x509_name_get_entry(subject, index)
    return Result::Error if name_entry.null?

    asn1 = LibCrypto.x509_name_entry_get_data(name_entry)
    return Result::Error if asn1.null?

    str = LibCrypto.asn1_string_data(asn1)
    str_len = LibCrypto.asn1_string_length(asn1)
    return Result::MalformedCertificate if str_len != LibC.strlen(str)

    common_name = String.new(str, str_len)
    return Result::MatchFound if matches_hostname?(common_name, hostname)

    Result::MatchNotFound
  end

  # Matches a hostname against a wildcard pattern.
  #
  # The hostname must be an exact match or use a wildcard following
  # [RFC 6125, section 6.4.3](http://tools.ietf.org/html/rfc6125#section-6.4.3)
  # and [RFC 6125, section 7.2](http://tools.ietf.org/html/rfc6125#section-7.2)
  #
  # IDNA domains must be given in their punycode encoding, and no wildcard match
  # will be attempted if the left-most label is an IDNA label. For example
  # `*.xn--kcry6tjko.example.org` will match `foo.xn--kcry6tjko.example.org` but
  # `xn--*.example.org` won't match `xn--kcry6tjko.example.org`.
  #
  # No wildcard match is attempted for IP addresses. The hostname and patterns
  # are normalized to skip trailing dots (like browsers do).
  #
  # To be compatible with OpenSSL `X509_check_host` a leading dot will match any
  # subdomain. For example `.example.org` will match both `foo.example.com` and
  # `bar.foo.example.com`.
  #
  # Adapted from cURL:
  # Copyright (C) 1998 - 2014, Daniel Stenberg, <daniel@haxx.se>, et al.
  # https://github.com/curl/curl/blob/curl-7_41_0/lib/hostcheck.c
  def self.matches_hostname?(pattern, hostname)
    pattern = pattern.chomp('.').downcase
    hostname = hostname.chomp('.').downcase

    # leading dot matches any subdomain (openssl 1.0.2 compatibility)
    if pattern[0] == '.'
      return hostname.ends_with?(pattern)
    end

    unless wildcard = pattern.index('*')
      return pattern == hostname
    end

    # fail match when hostname is an IP address
    if ::Socket.ip?(hostname)
      return false
    end

    unless pattern_label_len = pattern.index('.')
      return false
    end

    # only the first label should be considered for wildcard match
    # need at least 2 dots in pattern to avoid too wide wildcard match
    # no wildcard match in IDNA label
    if wildcard > pattern_label_len || pattern.count('.') < 2 || pattern.starts_with?("xn--")
      return pattern == hostname
    end

    unless hostname_label_len = hostname.index('.')
      return false
    end

    # the wildcard must match at least 1 char, so the first label must be at least
    # the same size than pattern first label
    if hostname_label_len < pattern_label_len
      return false
    end

    # domains don't match
    if pattern[pattern_label_len..-1] != hostname[hostname_label_len..-1]
      return false
    end

    # wildcard match
    suffix = pattern_label_len - (wildcard + 1)
    pattern[0, wildcard] == hostname[0, wildcard] &&
      pattern[wildcard + 1, suffix + 1] == hostname[hostname_label_len - suffix, suffix + 1]
  end
end
