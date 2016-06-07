require "spec"
require "openssl"

describe "OpenSSL::X509::Name" do
  it "parse" do
    name = OpenSSL::X509::Name.parse("CN=nobody/DC=example")
    name.to_a.should eq([{"CN", "nobody"}, {"DC", "example"}])

    expect_raises(OpenSSL::Error) do
      OpenSSL::X509::Name.parse("CN=nobody/Unknown=Value")
    end
  end

  it "add_entry" do
    name = OpenSSL::X509::Name.new
    name.to_a.size.should eq(0)

    name.add_entry "CN", "Nobody"
    name.to_a.should eq([{"CN", "Nobody"}])

    name.add_entry "DC", "Example"
    name.to_a.should eq([{"CN", "Nobody"}, {"DC", "Example"}])

    expect_raises(OpenSSL::Error) { name.add_entry "UNKNOWN", "Value" }
  end
end
