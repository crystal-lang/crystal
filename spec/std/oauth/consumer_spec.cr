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
  end
end
