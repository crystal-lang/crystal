require "spec"
require "oauth"

describe OAuth::Consumer do
  describe "gets authorize uri" do
    it "without callback url" do
      consumer = OAuth::Consumer.new "example.com", "consumer_key", "consumer_secret"
      request_token = OAuth::RequestToken.new "request_token", "request_secret"
      uri = consumer.get_authorize_uri request_token
      uri.should eq("https://example.com/oauth/authorize?oauth_token=request_token")
    end

    it "with callback url" do
      consumer = OAuth::Consumer.new "example.com", "consumer_key", "consumer_secret"
      request_token = OAuth::RequestToken.new "request_token", "request_secret"
      uri = consumer.get_authorize_uri request_token, oauth_callback: "some_callback"
      uri.should eq("https://example.com/oauth/authorize?oauth_token=request_token&oauth_callback=some_callback")
    end

    it "without custom authorize uri" do
      consumer = OAuth::Consumer.new "example.com", "consumer_key", "consumer_secret", authorize_uri: "/foo"
      request_token = OAuth::RequestToken.new "request_token", "request_secret"
      uri = consumer.get_authorize_uri request_token
      uri.should eq("https://example.com/foo?oauth_token=request_token")
    end

    it "without block" do
      consumer = OAuth::Consumer.new "example.com", "consumer_key", "consumer_secret"
      request_token = OAuth::RequestToken.new "request_token", "request_secret"
      uri = consumer.get_authorize_uri(request_token) do |form|
        form.add "baz", "qux"
      end
      uri.should eq("https://example.com/oauth/authorize?oauth_token=request_token&baz=qux")
    end

    it "with absolute uri" do
      consumer = OAuth::Consumer.new "example.com", "consumer_key", "consumer_secret",
        authorize_uri: "https://example2.com:1234/foo?bar=baz"
      request_token = OAuth::RequestToken.new "request_token", "request_secret"
      uri = consumer.get_authorize_uri request_token
      uri.should eq("https://example2.com:1234/foo?oauth_token=request_token&bar=baz")
    end
  end

  typeof(begin
    consumer = OAuth::Consumer.new "example.com", "consumer_key", "consumer_secret", authorize_uri: "/foo"
    consumer.get_request_token(oauth_callback: "foo.bar.baz")

    request_token = OAuth::RequestToken.new "request_token", "request_secret"
    consumer.get_access_token(request_token, "oauth_verifier")
    consumer.get_access_token(request_token, "oauth_verifier", {"a" => "b"})

    access_token = OAuth::AccessToken.new "token", "secret"

    http_client = HTTP::Client.new "example.com"
    consumer.authenticate http_client, access_token
  end)
end
