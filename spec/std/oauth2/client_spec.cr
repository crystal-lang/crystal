require "spec"
require "oauth2"
require "http/server"
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
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http"
          client.http_client = http_client

          token = client.get_access_token_using_authorization_code(authorization_code: "SDFhw39fwfg23flSfpawbef")
          token.extra.not_nil!["body"].should eq %("redirect_uri=&grant_type=authorization_code&code=SDFhw39fwfg23flSfpawbef")
          token.access_token.should eq "access_token"
        end
      end

      it "configures HTTP::Client" do
        server = HTTP::Server.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end
        address = server.bind_tcp 0

        run_server(server) do
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", port: address.port, scheme: "http"
          client.http_client.port.should eq address.port
          client.http_client.host.should eq "127.0.0.1"

          token = client.get_access_token_using_authorization_code(authorization_code: "SDFhw39fwfg23flSfpawbef")
          token.extra.not_nil!["body"].should eq %("redirect_uri=&grant_type=authorization_code&code=SDFhw39fwfg23flSfpawbef")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_resource_owner_credentials" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http"
          client.http_client = http_client

          token = client.get_access_token_using_resource_owner_credentials(username: "user123", password: "monkey", scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("grant_type=password&username=user123&password=monkey&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_client_credentials" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http"
          client.http_client = http_client

          token = client.get_access_token_using_client_credentials(scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("grant_type=client_credentials&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_refresh_token" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http"
          client.http_client = http_client

          token = client.get_access_token_using_refresh_token(scope: "read_posts", refresh_token: "some_refresh_token")
          token.extra.not_nil!["body"].should eq %("grant_type=refresh_token&refresh_token=some_refresh_token&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#make_token_request" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          dpop = context.request.headers.get?("DPoP")
          response = {access_token: "access_token", body: body, dpop: dpop}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http"
          client.http_client = http_client

          token_response = client.make_token_request do |form, headers|
            form.add("redirect_uri", client.redirect_uri)
            form.add("grant_type", "authorization_code")
            form.add("code", "some_authorization_code")
            form.add("code_verifier", "a_code_verifier")
            form.add("nonce", "a_nonce")
            headers.add("DPoP", "a_DPoP_jwt_token")
          end
          token_response.status_code.should eq(200)
          token = OAuth2::AccessToken.from_json(token_response.body)
          token.extra.not_nil!["body"].should eq %("redirect_uri=&grant_type=authorization_code&code=some_authorization_code&code_verifier=a_code_verifier&nonce=a_nonce")
          token.extra.not_nil!["dpop"].should eq %(["a_DPoP_jwt_token"])
          token.access_token.should eq "access_token"
        end
      end
    end
    describe "using Request Body to pass credentials" do
      it "#get_access_token_using_authorization_code" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody
          client.http_client = http_client

          token = client.get_access_token_using_authorization_code(authorization_code: "SDFhw39fwfg23flSfpawbef")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&redirect_uri=&grant_type=authorization_code&code=SDFhw39fwfg23flSfpawbef")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_resource_owner_credentials" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody
          client.http_client = http_client

          token = client.get_access_token_using_resource_owner_credentials(username: "user123", password: "monkey", scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=password&username=user123&password=monkey&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_client_credentials" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody
          client.http_client = http_client

          token = client.get_access_token_using_client_credentials(scope: "read_posts")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=client_credentials&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#get_access_token_using_refresh_token" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          response = {access_token: "access_token", body: body}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody
          client.http_client = http_client

          token = client.get_access_token_using_refresh_token(scope: "read_posts", refresh_token: "some_refresh_token")
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=refresh_token&refresh_token=some_refresh_token&scope=read_posts")
          token.access_token.should eq "access_token"
        end
      end

      it "#make_token_request" do
        handler = HTTP::Handler::HandlerProc.new do |context|
          body = context.request.body.not_nil!.gets_to_end
          dpop = context.request.headers.get?("DPoP")
          response = {access_token: "access_token", body: body, dpop: dpop}
          context.response.print response.to_json
        end

        run_handler(handler) do |http_client|
          client = OAuth2::Client.new "127.0.0.1", "client_id", "client_secret", scheme: "http", auth_scheme: OAuth2::AuthScheme::RequestBody
          client.http_client = http_client

          token_response = client.make_token_request do |form, headers|
            form.add("grant_type", "refresh_token")
            form.add("refresh_token", "some_refresh_token")
            form.add("scope", "read_posts")
            form.add("nonce", "a_nonce")
            headers.add("DPoP", "a_DPoP_jwt_token")
          end
          token_response.status_code.should eq(200)
          token = OAuth2::AccessToken.from_json(token_response.body)
          token.extra.not_nil!["body"].should eq %("client_id=client_id&client_secret=client_secret&grant_type=refresh_token&refresh_token=some_refresh_token&scope=read_posts&nonce=a_nonce")
          token.extra.not_nil!["dpop"].should eq %(["a_DPoP_jwt_token"])
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
