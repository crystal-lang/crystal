require "http/server"
require "crypto/bcrypt"

class Thread
  def prng
    @prng ||= Random::PCG32.new
  end
end

i = 0

server = HTTP::Server.new do |ctx|
  ctx.response.headers["content-type"] = "text/plain"

  case ctx.request.path
  when "/random"
    rng = Thread.current.prng
    ctx.response << "Random" << rng.rand << '\n'

  when "/secure"
    ctx.response << "Random" << Random::Secure.rand << '\n'

  when "/bcrypt"
    hash = Crypto::Bcrypt::Password.create("my super secret password", cost: 5)
    ctx.response << "bcrypt " << hash << '\n'

  when "/counter"
    ctx.response << "Hello #{i += 1}\n"

  else
    ctx.response.status_code = 404
    ctx.response << "404 Not Found\n"
  end
end
server.bind_tcp(9292, reuse_port: true)

puts "listening on :9292"
server.listen
