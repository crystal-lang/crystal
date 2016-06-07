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
end
