require "spec"
require "openssl/ssl/hostname_validation"

private def openssl_create_cert(subject = nil, san = nil)
  cert = OpenSSL::X509::Certificate.new
  cert.subject = subject if subject
  cert.add_extension(OpenSSL::X509::Extension.new("subjectAltName", san)) if san
  cert.to_unsafe
end

describe OpenSSL::SSL::HostnameValidation do
  describe "validate_hostname" do
    it "matches IP from certificate SAN entries" do
      OpenSSL::SSL::HostnameValidation.validate_hostname("192.168.1.1", openssl_create_cert(san: "IP:192.168.1.1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("192.168.1.2", openssl_create_cert(san: "IP:192.168.1.1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchNotFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("::1", openssl_create_cert(san: "IP:::1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("::1", openssl_create_cert(san: "IP:::2")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchNotFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("0:0:0:0:0:0:0:1", openssl_create_cert(san: "IP:::1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("fe80:0:0:0:0:0:0:1", openssl_create_cert(san: "IP:fe80::1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("fe80:0:0:0:0:0:0:2", openssl_create_cert(san: "IP:fe80::1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchNotFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("fe80:0:1", openssl_create_cert(san: "IP:fe80:0::1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchNotFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("fe80::0:1", openssl_create_cert(san: "IP:fe80:0::1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
    end

    it "matches domains from certificate SAN entries" do
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.com", openssl_create_cert(san: "DNS:example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.org", openssl_create_cert(san: "DNS:example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchNotFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("foo.example.com", openssl_create_cert(san: "DNS:*.example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
    end

    it "verifies all SAN entries" do
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.com", openssl_create_cert(san: "DNS:example.com,DNS:example.org")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("10.0.3.1", openssl_create_cert(san: "IP:192.168.1.1,IP:10.0.3.1")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.com", openssl_create_cert(san: "IP:192.168.1.1,DNS:example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
    end

    it "falls back to CN entry (unless SAN entry is defined)" do
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.com", openssl_create_cert(subject: "CN=example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.com", openssl_create_cert(san: "DNS:example.org", subject: "CN=example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchNotFound)
      OpenSSL::SSL::HostnameValidation.validate_hostname("example.org", openssl_create_cert(san: "DNS:example.org", subject: "CN=example.com")).should eq(OpenSSL::SSL::HostnameValidation::Result::MatchFound)
    end
  end

  describe "matches_hostname?" do
    it "skips trailing dot" do
      OpenSSL::SSL::HostnameValidation.matches_hostname?("example.com.", "example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("example.com", "example.com.").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?(".example.com", "example.com").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?("example.com", ".example.com").should be_false
    end

    it "normalizes case" do
      OpenSSL::SSL::HostnameValidation.matches_hostname?("exAMPLE.cOM", "EXample.Com").should be_true
    end

    it "literal matches" do
      OpenSSL::SSL::HostnameValidation.matches_hostname?("example.com", "example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("example.com", "www.example.com").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?("www.example.com", "www.example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("foo.bar.example.com", "bar.example.com").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?("foo.bar.example.com", "foo.bar.example.com").should be_true
    end

    it "wildcard matches according to RFC 6125, section 6.4.3" do
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.com", "example.com").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?("bar.*.example.com", "bar.foo.example.com").should be_false

      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.example.com", "foo.example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.example.com", "foo.example.org").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.example.com", "bar.foo.example.com").should be_false

      OpenSSL::SSL::HostnameValidation.matches_hostname?("baz*.example.com", "baz1.example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("baz*.example.com", "baz.example.com").should be_false

      OpenSSL::SSL::HostnameValidation.matches_hostname?("*baz.example.com", "foobaz.example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*baz.example.com", "baz.example.com").should be_false

      OpenSSL::SSL::HostnameValidation.matches_hostname?("b*z.example.com", "buzz.example.com").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("b*z.example.com", "bz.example.com").should be_false

      OpenSSL::SSL::HostnameValidation.matches_hostname?("192.168.0.1", "192.168.0.1").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.168.0.1", "192.168.0.1").should be_false
    end

    it "matches IDNA label" do
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.example.org", "xn--kcry6tjko.example.org").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("*.xn--kcry6tjko.example.org", "foo.xn--kcry6tjko.example.org").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?("xn--*.example.org", "xn--kcry6tjko.example.org").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?("xn--kcry6tjko*.example.org", "xn--kcry6tjkofoo.example.org").should be_false
    end

    it "matches leading dot" do
      OpenSSL::SSL::HostnameValidation.matches_hostname?(".example.org", "example.org").should be_false
      OpenSSL::SSL::HostnameValidation.matches_hostname?(".example.org", "xn--kcry6tjko.example.org").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?(".example.org", "foo.example.org").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?(".example.org", "foo.bar.example.org").should be_true
      OpenSSL::SSL::HostnameValidation.matches_hostname?(".example.org", "foo.example.com").should be_false
    end
  end
end
