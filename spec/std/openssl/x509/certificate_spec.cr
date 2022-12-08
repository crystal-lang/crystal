require "spec"
require "openssl"

describe OpenSSL::X509::Certificate do
  it "subject" do
    cert = OpenSSL::X509::Certificate.new
    cert.subject = "CN=Nobody/DC=example"
    cert.subject.to_a.should eq([{"CN", "Nobody"}, {"DC", "example"}])
  end

  it "extension" do
    cert = OpenSSL::X509::Certificate.new

    cert.add_extension OpenSSL::X509::Extension.new("subjectAltName", "IP:127.0.0.1")
    cert.extensions.map(&.oid).should eq ["subjectAltName"]
    cert.extensions.map(&.value).should eq ["IP Address:127.0.0.1"]

    cert.add_extension OpenSSL::X509::Extension.new("subjectAltName", "DNS:localhost.localdomain")
    cert.extensions.map(&.oid).should eq ["subjectAltName", "subjectAltName"]
    cert.extensions.map(&.value).should eq ["IP Address:127.0.0.1", "DNS:localhost.localdomain"]
  end

  it "#signature_algorithm" do
    cert = OpenSSL::X509::Certificate.new

    expect_raises(Exception, "Could not determine certificate signature algorithm") do
      cert.signature_algorithm
    end
  end

  # Starting with 3.0.0 OpenSSL complains about generating a digest signature for an empty certificate
  {% if compare_versions(LibSSL::OPENSSL_VERSION, "3.0.0") < 0 %}
    it "#digest" do
      cert = OpenSSL::X509::Certificate.new
      expect_raises(ArgumentError, %(Could not find digest for "not a real algo")) { cert.digest("not a real algo") }
      cert.digest("SHA256").should_not be_nil
    end
  {% else %}
    pending "#digest"
  {% end %}
end
