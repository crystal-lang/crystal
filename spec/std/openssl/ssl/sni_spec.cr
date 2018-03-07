require "spec"
require "socket"
require "openssl"
<<-EOC
To regenerate keys, run:
openssl genrsa -out server.key 2048
openssl req -sha256 -new -key server.key -out server.csr -subj '/CN=localhost'
openssl x509 -req -sha256 -days 3650 -in server.csr -signkey server.key -out server.crt
rm server.csr
EOC

# create a server context with private key and certificate chain set
def new_server_context
  ctx = OpenSSL::SSL::Context::Server.new
  ctx.private_key = File.join(__DIR__, "server.key")
  ctx.certificate_chain = File.join(__DIR__, "server.crt")
  ctx
end

# create a client context with CA certificates set to include the default self-signed server certificate
def new_client_context
  ctx = OpenSSL::SSL::Context::Client.new
  ctx.ca_certificates = File.join(__DIR__, "server.crt")
  ctx
end

# run an ssl server with the supplied server context and port
def run_server(q, port, tls = nil)
  q.send "start"
  tcp_server = TCPServer.new port
  while 1
    if io = tcp_server.accept?
      context = if tls
                  tls
                else
                  new_server_context
                end
      begin
        ssl_server = OpenSSL::SSL::Socket::Server.new io, context
      rescue e
        # Errors will occur here if SNI doesn't return SSL_ERR_OK.
        # Other errors are possible, but this spec tests SNI assuming other components are functional.
        break
      end
      ssl_server = ssl_server.not_nil!
      msg = ssl_server.gets
      ssl_server.puts msg
      ssl_server.flush
      ssl_server.close
      io.close
      break
    end
  end
  tcp_server.close
  q.send "done"
end

# starts an SSL server, connects to it, and sends and receives a line of text
# If hostname is supplied, SNI will receive anon-null hostname.
def run_client(port, hostname = nil, client_context = nil, server_context = nil)
  q = Channel(String).new(1)
  spawn do
    run_server q, port, server_context
  end
  client_ctx = if client_context
                 client_context
               else
                 new_client_context
               end
  q.receive
  tcp_client = TCPSocket.new "localhost", port
  ssl_client = OpenSSL::SSL::Socket::Client.new io: tcp_client, context: client_ctx.not_nil!, hostname: hostname
  ssl_client.puts "abcde"
  ssl_client.flush
  ssl_client.gets.should eq "abcde"
  ssl_client.close
  tcp_client.close
  q.receive
end

describe OpenSSL::SSL::Socket::Server do
  port = 21001
  it "connects without provided sni hostname" do
    run_client port, nil, nil, nil
  end
  it "connects with provided sni hostname" do
    run_client port, "localhost", nil, nil
  end
  it "functions when no hostname is submitted and when SNI is checked but not required" do
    server_context = new_server_context
    sni_context = new_server_context
    server_context.sni_fail_hard = false
    server_context.add_sni_hostname "invalid_hostname", sni_context
    run_client port: port, server_context: server_context
  end
  it "raises when no SNI hostname is submitted but SNI is required" do
    server_context = new_server_context
    sni_context = new_server_context
    server_context.sni_fail_hard = true
    server_context.add_sni_hostname "invalid_hostname", sni_context
    # get_client_hello shows up on OpenSSL <1.0.1f
    expect_raises OpenSSL::SSL::Error, /get_server_hello|get_client_hello/i do
      run_client port: port, server_context: server_context
    end
  end
  it "raises when invalid SNI hostname is submitted and SNI is required" do
    server_context = new_server_context
    sni_context = new_server_context
    server_context.sni_fail_hard = true
    server_context.add_sni_hostname "localhost", sni_context
    client_context = new_client_context
    # disable peer verification so we can be sure error is coming from SNI
    client_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
    expect_raises OpenSSL::SSL::Error, /get_server_hello|get_client_hello/i do
      run_client port: port, server_context: server_context, hostname: "client_supplied_invalid_hostname"
    end
  end
  it "functions when SNI is required and valid SNI is supplied" do
    server_context = new_server_context
    sni_context = new_server_context
    server_context.sni_fail_hard = true
    server_context.add_sni_hostname "localhost", sni_context
    run_client port: port, server_context: server_context, hostname: "localhost"
  end
  it "adds multiple hostnames for a context" do
    server_context = new_server_context
    sni_context = new_server_context
    server_context.add_sni_hostnames ["somehost", "localhost"], sni_context
    server_context.sni_fail_hard = true
    run_client port: port, server_context: server_context, hostname: "localhost"
  end
end
GC.collect
