require "spec"
require "oauth2"

describe OAuth2::Client do
  describe "authorization uri" do
    it "gets with default endpoint" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri"
      uri = client.get_authorize_uri(scope: "foo bar")
      uri.should eq("https://localhost/oauth2/authorize?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar")
    end

    it "gets with custom endpoint" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri", authorize_uri: "/baz"
      uri = client.get_authorize_uri(scope: "foo bar")
      uri.should eq("https://localhost/baz?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar")
    end

    it "gets with state" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri"
      uri = client.get_authorize_uri(scope: "foo bar", state: "xyz")
      uri.should eq("https://localhost/oauth2/authorize?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar&state=xyz")
    end

    it "gets with block" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri"
      uri = client.get_authorize_uri(scope: "foo bar") do |form|
        form.add "baz", "qux"
      end
      uri.should eq("https://localhost/oauth2/authorize?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar&baz=qux")
    end

    it "gets with absolute uri" do
      client = OAuth2::Client.new "localhost", "client_id", "client_secret",
        redirect_uri: "uri",
        authorize_uri: "https://example2.com:1234/foo?bar=baz"
      uri = client.get_authorize_uri(scope: "foo bar")
      uri.should eq("https://example2.com:1234/foo?client_id=client_id&redirect_uri=uri&response_type=code&scope=foo+bar&bar=baz")
    end
  end

  typeof(begin
    client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri", authorize_uri: "/baz"
    client.get_access_token_using_authorization_code("some_code")
    client.get_access_token_using_refresh_token("some_refresh_token")
    client.get_access_token_using_refresh_token("some_refresh_token", scope: "some scope")
    client.get_access_token_using_client_credentials(scope: "some scope")
  end)
end
