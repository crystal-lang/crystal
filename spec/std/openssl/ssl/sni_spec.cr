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
  tcpServer = TCPServer.new port
  while 1
    if io = tcpServer.accept?
      context = if tls
                  tls
                else
                  new_server_context
                end
      begin
        sslServer = OpenSSL::SSL::Socket::Server.new io, context
      rescue e
        # Errors will occur here if SNI doesn't return SSL_ERR_OK.
        # Other errors are possible, but this spec tests SNI assuming other components are functional.
        break
      end
      sslServer = sslServer.not_nil!
      msg = sslServer.gets
      sslServer.puts msg
      sslServer.close
      io.close
      break
    end
  end
  tcpServer.close
  q.send "done"
end

# starts an SSL server, connects to it, and sends and receives a line of text
# If hostname is supplied, SNI will receive anon-null hostname.
def run_client(port, hostname = nil, client_context = nil, server_context = nil)
  q = Channel(String).new(1)
  spawn do
    run_server q, port, server_context
  end
  clientCtx = if client_context
                client_context
              else
                new_client_context
              end
  q.receive
  tcpClient = TCPSocket.new "localhost", port
  sslClient = OpenSSL::SSL::Socket::Client.new io: tcpClient, context: clientCtx.not_nil!, hostname: hostname
  sslClient.puts "abcde"
  sslClient.flush
  sslClient.gets.should eq "abcde"
  sslClient.close
  tcpClient.close
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
  it "functions with non-existing hostname when SNI is checked but not required" do
    serverContext = new_server_context
    sniContext = new_server_context
    serverContext.sni_fail_hard = false
    serverContext.add_sni_hostname "invalid_hostname", sniContext
    run_client port: port, server_context: serverContext
  end
  it "raises when no SNI hostname is submitted but SNI is required" do
    serverContext = OpenSSL::SSL::Context::Server.new
    sniContext = new_server_context
    serverContext.sni_fail_hard = true
    serverContext.add_sni_hostname "invalid_hostname", sniContext
    expect_raises OpenSSL::SSL::Error, /get_server_hello/i do
      run_client port: port, server_context: serverContext
    end
  end
  it "raises when invalid SNI hostname is submitted and SNI is required" do
    serverContext = OpenSSL::SSL::Context::Server.new
    sniContext = new_server_context
    serverContext.sni_fail_hard = true
    serverContext.add_sni_hostname "localhost", sniContext
    clientContext = new_client_context
    # disable peer verification so we can be sure error is coming from SNI
    clientContext.verify_mode = OpenSSL::SSL::VerifyMode::NONE
    expect_raises OpenSSL::SSL::Error, /get_server_hello/i do
      run_client port: port, server_context: serverContext, hostname: "client_supplied_invalid_hostname"
    end
  end
  it "functions when SNI is required and valid SNI is supplied" do
    serverContext = OpenSSL::SSL::Context::Server.new
    sniContext = new_server_context
    serverContext.sni_fail_hard = true
    serverContext.add_sni_hostname "localhost", sniContext
    run_client port: port, server_context: serverContext, hostname: "localhost"
  end
end
