require "spec"
require "oauth2"

describe OAuth2::Client do
  describe "authorization uri" do
    it "gets with default endpoint" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri"
      uri = client.authorize_uri(scope: "foo bar")
      uri.should eq("https://localhost/oauth2/authorize?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar")
    end

    it "gets with custom endpoint" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri", authorize_uri: "/baz"
      uri = client.authorize_uri(scope: "foo bar")
      uri.should eq("https://localhost/baz?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar")
    end
  end
end
