require "spec"
require "openssl"

describe OpenSSL::SSL::Context do
  it "new for client" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    ssl_context.options.should eq(OpenSSL::SSL.options_flags(
      ALL, NO_SSLV2, NO_SSLV3, NO_SESSION_RESUMPTION_ON_RENEGOTIATION, SINGLE_ECDH_USE, SINGLE_DH_USE
    ))
    ssl_context.modes.should eq(OpenSSL::SSL.modes_flags(AUTO_RETRY, RELEASE_BUFFERS))
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::PEER)

    OpenSSL::SSL::Context::Client.new(LibSSL.tlsv1_method)
  end

  it "new for server" do
    ssl_context = OpenSSL::SSL::Context::Server.new
    ssl_context.options.should eq(OpenSSL::SSL.options_flags(
      ALL, NO_SSLV2, NO_SSLV3, NO_SESSION_RESUMPTION_ON_RENEGOTIATION, SINGLE_ECDH_USE, SINGLE_DH_USE, CIPHER_SERVER_PREFERENCE
    ))
    ssl_context.modes.should eq(OpenSSL::SSL.modes_flags(AUTO_RETRY, RELEASE_BUFFERS))
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)

    OpenSSL::SSL::Context::Server.new(LibSSL.tlsv1_method)
  end

  it "insecure for client" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.should be_a(OpenSSL::SSL::Context::Client)
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    ssl_context.options.no_ssl_v3?.should_not be_true
    ssl_context.modes.should eq(OpenSSL::SSL::Modes::None)

    OpenSSL::SSL::Context::Client.insecure(LibSSL.tlsv1_method)
  end

  it "insecure for server" do
    ssl_context = OpenSSL::SSL::Context::Server.insecure
    ssl_context.should be_a(OpenSSL::SSL::Context::Server)
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    ssl_context.options.no_ssl_v3?.should_not be_true
    ssl_context.modes.should eq(OpenSSL::SSL::Modes::None)

    OpenSSL::SSL::Context::Server.insecure(LibSSL.tlsv1_method)
  end

  it "sets certificate chain" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    ssl_context.certificate_chain = File.join(__DIR__, "openssl.crt")
  end

  it "fails to set certificate chain" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    expect_raises(OpenSSL::Error) { ssl_context.certificate_chain = File.join(__DIR__, "unknown.crt") }
    expect_raises(OpenSSL::Error) { ssl_context.certificate_chain = __FILE__ }
  end

  it "sets private key" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    ssl_context.private_key = File.join(__DIR__, "openssl.key")
  end

  it "fails to set private key" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    expect_raises(OpenSSL::Error) { ssl_context.private_key = File.join(__DIR__, "unknown.key") }
    expect_raises(OpenSSL::Error) { ssl_context.private_key = __FILE__ }
  end

  it "sets ciphers" do
    ciphers = "EDH+aRSA DES-CBC3-SHA !RC4"
    ssl_context = OpenSSL::SSL::Context::Client.new
    (ssl_context.ciphers = ciphers).should eq(ciphers)
  end

  it "adds temporary ecdh curve (P-256)" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    ssl_context.set_tmp_ecdh_key
  end

  it "adds options" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    ssl_context.remove_options(ssl_context.options) # reset
    ssl_context.add_options(OpenSSL::SSL::Options::ALL).should eq(OpenSSL::SSL::Options::ALL)
    ssl_context.add_options(OpenSSL::SSL.options_flags(NO_SSLV2, NO_SSLV3))
               .should eq(OpenSSL::SSL.options_flags(ALL, NO_SSLV2, NO_SSLV3))
  end

  it "removes options" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.add_options(OpenSSL::SSL.options_flags(ALL, NO_SSLV2))
    ssl_context.remove_options(OpenSSL::SSL::Options::ALL).should eq(OpenSSL::SSL::Options::NO_SSLV2)
  end

  it "returns options" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.add_options(OpenSSL::SSL.options_flags(ALL, NO_SSLV2))
    ssl_context.options.should eq(OpenSSL::SSL.options_flags(ALL, NO_SSLV2))
  end

  it "adds modes" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.add_modes(OpenSSL::SSL::Modes::AUTO_RETRY).should eq(OpenSSL::SSL::Modes::AUTO_RETRY)
    ssl_context.add_modes(OpenSSL::SSL::Modes::RELEASE_BUFFERS)
               .should eq(OpenSSL::SSL.modes_flags(AUTO_RETRY, RELEASE_BUFFERS))
  end

  it "removes modes" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.add_modes(OpenSSL::SSL.modes_flags(AUTO_RETRY, RELEASE_BUFFERS))
    ssl_context.remove_modes(OpenSSL::SSL::Modes::AUTO_RETRY).should eq(OpenSSL::SSL::Modes::RELEASE_BUFFERS)
  end

  it "returns modes" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.add_modes(OpenSSL::SSL.modes_flags(AUTO_RETRY, RELEASE_BUFFERS))
    ssl_context.modes.should eq(OpenSSL::SSL.modes_flags(AUTO_RETRY, RELEASE_BUFFERS))
  end

  it "sets the verify mode" do
    ssl_context = OpenSSL::SSL::Context::Client.new
    ssl_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    ssl_context.verify_mode = OpenSSL::SSL::VerifyMode::PEER
    ssl_context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::PEER)
  end

  {% if LibSSL::OPENSSL_102 %}
  it "alpn_protocol=" do
    ssl_context = OpenSSL::SSL::Context::Client.insecure
    ssl_context.alpn_protocol = "h2"
  end
  {% end %}
end
