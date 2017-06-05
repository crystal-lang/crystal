require "spec"
require "openssl"

describe OpenSSL::SSL::Context do
  it "new for client" do
    context = OpenSSL::SSL::Context::Client.new

    (context.options & OpenSSL::SSL::Options::ALL).should eq(OpenSSL::SSL::Options::ALL)
    (context.options & OpenSSL::SSL::Options::NO_SSL_V2).should eq(OpenSSL::SSL::Options::NO_SSL_V2)
    (context.options & OpenSSL::SSL::Options::NO_SSL_V3).should eq(OpenSSL::SSL::Options::NO_SSL_V3)
    (context.options & OpenSSL::SSL::Options::NO_SESSION_RESUMPTION_ON_RENEGOTIATION).should eq(OpenSSL::SSL::Options::NO_SESSION_RESUMPTION_ON_RENEGOTIATION)
    (context.options & OpenSSL::SSL::Options::SINGLE_ECDH_USE).should eq(OpenSSL::SSL::Options::SINGLE_ECDH_USE)
    (context.options & OpenSSL::SSL::Options::SINGLE_DH_USE).should eq(OpenSSL::SSL::Options::SINGLE_DH_USE)

    context.modes.should eq(OpenSSL::SSL::Modes.flags(AUTO_RETRY, RELEASE_BUFFERS))
    context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::PEER)

    OpenSSL::SSL::Context::Client.new(LibSSL.tlsv1_method)
  end

  it "new for server" do
    context = OpenSSL::SSL::Context::Server.new

    (context.options & OpenSSL::SSL::Options::ALL).should eq(OpenSSL::SSL::Options::ALL)
    (context.options & OpenSSL::SSL::Options::NO_SSL_V2).should eq(OpenSSL::SSL::Options::NO_SSL_V2)
    (context.options & OpenSSL::SSL::Options::NO_SSL_V3).should eq(OpenSSL::SSL::Options::NO_SSL_V3)
    (context.options & OpenSSL::SSL::Options::NO_SESSION_RESUMPTION_ON_RENEGOTIATION).should eq(OpenSSL::SSL::Options::NO_SESSION_RESUMPTION_ON_RENEGOTIATION)
    (context.options & OpenSSL::SSL::Options::SINGLE_ECDH_USE).should eq(OpenSSL::SSL::Options::SINGLE_ECDH_USE)
    (context.options & OpenSSL::SSL::Options::SINGLE_DH_USE).should eq(OpenSSL::SSL::Options::SINGLE_DH_USE)
    (context.options & OpenSSL::SSL::Options::CIPHER_SERVER_PREFERENCE).should eq(OpenSSL::SSL::Options::CIPHER_SERVER_PREFERENCE)

    context.modes.should eq(OpenSSL::SSL::Modes.flags(AUTO_RETRY, RELEASE_BUFFERS))
    context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)

    OpenSSL::SSL::Context::Server.new(LibSSL.tlsv1_method)
  end

  it "insecure for client" do
    context = OpenSSL::SSL::Context::Client.insecure
    context.should be_a(OpenSSL::SSL::Context::Client)
    context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    context.options.no_ssl_v3?.should_not be_true
    context.modes.should eq(OpenSSL::SSL::Modes::None)

    OpenSSL::SSL::Context::Client.insecure(LibSSL.tlsv1_method)
  end

  it "insecure for server" do
    context = OpenSSL::SSL::Context::Server.insecure
    context.should be_a(OpenSSL::SSL::Context::Server)
    context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    context.options.no_ssl_v3?.should_not be_true
    context.modes.should eq(OpenSSL::SSL::Modes::None)

    OpenSSL::SSL::Context::Server.insecure(LibSSL.tlsv1_method)
  end

  it "sets certificate chain" do
    context = OpenSSL::SSL::Context::Client.new
    context.certificate_chain = File.join(__DIR__, "openssl.crt")
  end

  it "fails to set certificate chain" do
    context = OpenSSL::SSL::Context::Client.new
    expect_raises(OpenSSL::Error) { context.certificate_chain = File.join(__DIR__, "unknown.crt") }
    expect_raises(OpenSSL::Error) { context.certificate_chain = __FILE__ }
  end

  it "sets private key" do
    context = OpenSSL::SSL::Context::Client.new
    context.private_key = File.join(__DIR__, "openssl.key")
  end

  it "fails to set private key" do
    context = OpenSSL::SSL::Context::Client.new
    expect_raises(OpenSSL::Error) { context.private_key = File.join(__DIR__, "unknown.key") }
    expect_raises(OpenSSL::Error) { context.private_key = __FILE__ }
  end

  it "sets ciphers" do
    ciphers = "EDH+aRSA DES-CBC3-SHA !RC4"
    context = OpenSSL::SSL::Context::Client.new
    (context.ciphers = ciphers).should eq(ciphers)
  end

  it "adds temporary ecdh curve (P-256)" do
    context = OpenSSL::SSL::Context::Client.new
    context.set_tmp_ecdh_key
  end

  it "adds options" do
    context = OpenSSL::SSL::Context::Client.new
    context.remove_options(context.options) # reset
    default_options = context.options       # options we can't unset

    context.add_options(OpenSSL::SSL::Options::ALL)
           .should eq(default_options | OpenSSL::SSL::Options::ALL)

    context.add_options(OpenSSL::SSL::Options.flags(NO_SSL_V2, NO_SSL_V3))
           .should eq(OpenSSL::SSL::Options.flags(ALL, NO_SSL_V2, NO_SSL_V3))
  end

  it "removes options" do
    context = OpenSSL::SSL::Context::Client.insecure
    default_options = context.options
    context.add_options(OpenSSL::SSL::Options.flags(NO_TLS_V1, NO_SSL_V2))
    context.remove_options(OpenSSL::SSL::Options::NO_TLS_V1).should eq(default_options | OpenSSL::SSL::Options::NO_SSL_V2)
  end

  it "returns options" do
    context = OpenSSL::SSL::Context::Client.insecure
    default_options = context.options
    context.add_options(OpenSSL::SSL::Options.flags(ALL, NO_SSL_V2))
    context.options.should eq(default_options | OpenSSL::SSL::Options.flags(ALL, NO_SSL_V2))
  end

  it "adds modes" do
    context = OpenSSL::SSL::Context::Client.insecure
    context.add_modes(OpenSSL::SSL::Modes::AUTO_RETRY).should eq(OpenSSL::SSL::Modes::AUTO_RETRY)
    context.add_modes(OpenSSL::SSL::Modes::RELEASE_BUFFERS)
           .should eq(OpenSSL::SSL::Modes.flags(AUTO_RETRY, RELEASE_BUFFERS))
  end

  it "removes modes" do
    context = OpenSSL::SSL::Context::Client.insecure
    context.add_modes(OpenSSL::SSL::Modes.flags(AUTO_RETRY, RELEASE_BUFFERS))
    context.remove_modes(OpenSSL::SSL::Modes::AUTO_RETRY).should eq(OpenSSL::SSL::Modes::RELEASE_BUFFERS)
  end

  it "returns modes" do
    context = OpenSSL::SSL::Context::Client.insecure
    context.add_modes(OpenSSL::SSL::Modes.flags(AUTO_RETRY, RELEASE_BUFFERS))
    context.modes.should eq(OpenSSL::SSL::Modes.flags(AUTO_RETRY, RELEASE_BUFFERS))
  end

  it "sets the verify mode" do
    context = OpenSSL::SSL::Context::Client.new
    context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
    context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::NONE)
    context.verify_mode = OpenSSL::SSL::VerifyMode::PEER
    context.verify_mode.should eq(OpenSSL::SSL::VerifyMode::PEER)
  end

  {% if LibSSL::OPENSSL_102 %}
  it "alpn_protocol=" do
    context = OpenSSL::SSL::Context::Client.insecure
    context.alpn_protocol = "h2"
  end
  {% end %}
end
