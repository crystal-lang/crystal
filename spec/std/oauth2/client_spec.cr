require "spec"
require "oauth2"
require "../http/spec_helper"

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

  describe "get_access_token_using_*" do
    describe "using HTTP Basic authentication to pass credentials" do
      it "#get_access_token_using_authorization_code" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http"

          token = client.get_access_token_using_authorization_code(authorization_code: "SDFhw39fwfg23flSfpawbef")
          token.extra.not_nil!["body"].should eq %("redirect_uri=&grant_type=authorization_code&code=SDFhw39fwfg23flSfpawbef")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_resource_owner_credentials" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http"

          token = client.get_access_token_using_resource_owner_credentials(username: "user123", password: "monkey", scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("grant_type=password&username=user123&password=monkey&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_client_credentials" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http"

          token = client.get_access_token_using_client_credentials(scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("grant_type=client_credentials&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_refresh_token" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http"

          token = client.get_access_token_using_refresh_token(scope: "read_posts", refresh_token: "some_refresh_token")
          token.extra.not_nil!["body"].should eq %("grant_type=refresh_token&refresh_token=some_refresh_token&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end
    end
    describe "using Request Body to pass credentials" do
      it "#get_access_token_using_authorization_code" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody

          token = client.get_access_token_using_authorization_code(authorization_code: "SDFhw39fwfg23flSfpawbef")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&redirect_uri=&grant_type=authorization_code&code=SDFhw39fwfg23flSfpawbef")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_resource_owner_credentials" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody

          token = client.get_access_token_using_resource_owner_credentials(username: "user123", password: "monkey", scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=password&username=user123&password=monkey&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_client_credentials" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody

          token = client.get_access_token_using_client_credentials(scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=client_credentials&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_refresh_token" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        address = server.bind_unused_port "::1"

        run_server(server) do
          client = OAuth2::Client.new "[::1]", "client_id", "client_secret", port: address.port, scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody

          token = client.get_access_token_using_refresh_token(scope: "read_posts", refresh_token: "some_refresh_token")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=refresh_token&refresh_token=some_refresh_token&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end
    end
  end

  typeof(begin
    client = OAuth2::Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri", authorize_uri: "/baz"
    client.get_access_token_using_authorization_code("some_code")
    client.get_access_token_using_refresh_token("some_refresh_token")
    client.get_access_token_using_refresh_token("some_refresh_token", scope: "some scope")
    client.get_access_token_using_client_credentials(scope: "some scope")
    client.get_access_token_using_resource_owner_credentials(username: "user123", password: "monkey")
    client.get_access_token_using_resource_owner_credentials(username: "user123", password: "monkey", scope: "foo")
  end)
end
