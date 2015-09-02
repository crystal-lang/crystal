require "spec"
require "http/client"

module HTTP
  describe Client do
    {% for method in %w(get post put head delete patch) %}
      typeof(Client.{{method.id}} "url")
      typeof(Client.new("host"))
      typeof(Client.new("host", port: 8080))
      typeof(Client.new("host", ssl: true))
      typeof(Client.new("host").{{method.id}}("uri"))
      typeof(Client.new("host").{{method.id}}("uri", headers: Headers {"Content-Type": "text/plain"}))
      typeof(Client.new("host").{{method.id}}("uri", body: "body"))
    {% end %}

    typeof(Client.post_form "url", {"a": "b"})
    typeof(Client.new("host").basic_auth("username", "password"))
    typeof(Client.new("host").before_request { |req| HTTP::Response.ok("text/plain", "OK") })
    typeof(Client.new("host").close)
    typeof(Client.get(URI.parse("http://www.example.com")))

    it "raises if URI is missing scheme" do
      expect_raises(ArgumentError) do
        HTTP::Client.get "www.example.com"
      end
    end
  end
end
