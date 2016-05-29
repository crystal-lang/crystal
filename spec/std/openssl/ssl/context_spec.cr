require "spec"
require "openssl"

describe OpenSSL::SSL::Context do
  it "new_for_client" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::PEER)
    OpenSSL::SSL::Context.new_for_client(LibSSL.tlsv1_method)
  end

  it "new_for_server" do
    ssl_context = OpenSSL::SSL::Context.new_for_server
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    OpenSSL::SSL::Context.new_for_server(LibSSL.tlsv1_method)
  end

  it "sets certificate chain" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.certificate_chain = File.join(__DIR__, "openssl.crt")
  end

  it "fails to set certificate chain" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    expect_raises(OpenSSL::Error) { ssl_context.certificate_chain = File.join(__DIR__, "unknown.crt") }
    expect_raises(OpenSSL::Error) { ssl_context.certificate_chain = __FILE__ }
  end

  it "sets private key" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.private_key = File.join(__DIR__, "openssl.key")
  end

  it "fails to set private key" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    expect_raises(OpenSSL::Error) { ssl_context.private_key = File.join(__DIR__, "unknown.key") }
    expect_raises(OpenSSL::Error) { ssl_context.private_key = __FILE__ }
  end

  it "sets ciphers" do
    ciphers = "EDH+aRSA DES-CBC3-SHA !RC4"
    ssl_context = OpenSSL::SSL::Context.new_for_client
    (ssl_context.ciphers = ciphers).should eq(ciphers)
  end

  it "adds temporary ecdh curve (P-256)" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.set_tmp_ecdh_key
  end

  it "adds options" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.remove_options(ssl_context.options) # reset
    ssl_context.add_options(LibSSL::Options::ALL).should eq(LibSSL::Options::ALL)
    ssl_context.add_options(LibSSL::Options::NO_SSLV2 | LibSSL::Options::NO_SSLV3)
               .should eq(LibSSL::Options::ALL | LibSSL::Options::NO_SSLV2 | LibSSL::Options::NO_SSLV3)
  end

  it "removes options" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.add_options(LibSSL::Options::ALL | LibSSL::Options::NO_SSLV2)
    ssl_context.remove_options(LibSSL::Options::ALL).should eq(LibSSL::Options::NO_SSLV2)
  end

  it "returns options" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.add_options(LibSSL::Options::ALL | LibSSL::Options::NO_SSLV2)
    ssl_context.options.should eq(LibSSL::Options::ALL | LibSSL::Options::NO_SSLV2)
  end

  it "adds modes" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.add_modes(LibSSL::Modes::AUTO_RETRY).should eq(LibSSL::Modes::AUTO_RETRY)
    ssl_context.add_modes(LibSSL::Modes::RELEASE_BUFFERS)
               .should eq(LibSSL::Modes::AUTO_RETRY | LibSSL::Modes::RELEASE_BUFFERS)
  end

  it "removes modes" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.add_modes(LibSSL::Modes::AUTO_RETRY | LibSSL::Modes::RELEASE_BUFFERS)
    ssl_context.remove_modes(LibSSL::Modes::AUTO_RETRY).should eq(LibSSL::Modes::RELEASE_BUFFERS)
  end

  it "returns modes" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.add_modes(LibSSL::Modes::AUTO_RETRY | LibSSL::Modes::RELEASE_BUFFERS)
    ssl_context.modes.should eq(LibSSL::Modes::AUTO_RETRY | LibSSL::Modes::RELEASE_BUFFERS)
  end

  it "sets the verify mode" do
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    ssl_context.verify_mode = OpenSSL::SSL::VerifyMode::PEER
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::PEER)
  end

  pending "alpn_protocol=" do
    # requires OpenSSL 1.0.2+
    ssl_context = OpenSSL::SSL::Context.new_for_client
    ssl_context.alpn_protocol = "h2"
  end
end
