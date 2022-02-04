require "openssl"

def ssl_context_pair
  server_context = OpenSSL::SSL::Context::Server.new
  server_context.certificate_chain = datapath("openssl", "openssl.crt")
  server_context.private_key = datapath("openssl", "openssl.key")

  client_context = OpenSSL::SSL::Context::Client.new
  client_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE

  {server_context, client_context}
end
