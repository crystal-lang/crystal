{% highlight ruby %}
# A very basic HTTP server
require "http/server"

server = HTTP::Server.new(8080) do |request|
  HTTP::Response.ok "text/plain", "Hello world, got #{request.path}!"
end

puts "Listening on http://0.0.0.0:8080"
server.listen
{% endhighlight %}
