require "spec"
require "oauth2"

class OAuth2::AccessToken
  describe Bearer do
    it "builds from json" do
      token_value = "some token value"
      token_type = "Bearer"
      expires_in = 3600
      refresh_token = "some refresh token"
      scope = "some scope"
      json = %({
        "access_token" : "#{token_value}",
        "token_type" : "#{token_type}",
        "expires_in" : #{expires_in},
        "refresh_token" : "#{refresh_token}",
        "scope" : "#{scope}"
        })

      access_token = AccessToken.from_json(json)
      access_token = access_token.as(Bearer)
      access_token.token_type.should eq("Bearer")
      access_token.access_token.should eq(token_value)
      access_token.expires_in.should eq(expires_in)
      access_token.refresh_token.should eq(refresh_token)
      access_token.scope.should eq(scope)

      access_token = AccessToken::Bearer.from_json(json)
      access_token = access_token.as(Bearer)
      access_token.token_type.should eq("Bearer")
      access_token.access_token.should eq(token_value)
      access_token.expires_in.should eq(expires_in)
      access_token.refresh_token.should eq(refresh_token)
      access_token.scope.should eq(scope)
    end

    it "dumps to json" do
      token = Bearer.new("access token", 3600, "refresh token")
      token2 = AccessToken.from_json(token.to_json)
      token2.should eq(token)
    end

    it "authenticates request" do
      token = Bearer.new("access token", 3600, "refresh token")
      request = HTTP::Request.new "GET", "/"
      token.authenticate request, false
      request.headers["Authorization"].should eq("Bearer access token")
    end

    it "builds from json without expires_in (#4041)" do
      access_token = AccessToken.from_json(%({
        "access_token" : "foo",
        "token_type" : "Bearer",
        "refresh_token" : "bar",
        "scope" : "baz"
        }))
      access_token.expires_in.should be_nil
    end

    it "builds from json with unknown key (#4437)" do
      token = AccessToken.from_json(%({
        "access_token" : "foo",
        "token_type" : "Bearer",
        "refresh_token" : "bar",
        "scope" : "baz",
        "unknown": [1, 2, 3]
        }))
      token.extra.not_nil!["unknown"].should eq("[1,2,3]")
    end

    it "builds from json without token_type, assumes Bearer (#4503)" do
      token = AccessToken.from_json(%({
        "access_token" : "foo",
        "refresh_token" : "bar",
        "scope" : "baz"
        }))
      token.should be_a(AccessToken::Bearer)
      token.access_token.should eq("foo")
    end
  end

  describe Mac do
    it "builds from json" do
      mac_algorithm = "hmac-sha-256"
      expires_in = 3600
      mac_key = "secret key"
      refresh_token = "some refresh token"
      token_value = "some token value"
      scope = "some scope"
      json = %({
          "token_type": "mac",
          "mac_algorithm": "#{mac_algorithm}",
          "expires_in": #{expires_in},
          "mac_key": "#{mac_key}",
          "refresh_token":"#{refresh_token}",
          "access_token":"#{token_value}",
          "scope":"#{scope}"
        })

      access_token = AccessToken.from_json(json)
      access_token = access_token.as(Mac)
      access_token.token_type.should eq("Mac")
      access_token.access_token.should eq(token_value)
      access_token.expires_in.should eq(expires_in)
      access_token.refresh_token.should eq(refresh_token)
      access_token.scope.should eq(scope)
      access_token.mac_algorithm.should eq(mac_algorithm)
      access_token.mac_key.should eq(mac_key)

      access_token = AccessToken::Mac.from_json(json)
      access_token = access_token.as(Mac)
      access_token.token_type.should eq("Mac")
      access_token.access_token.should eq(token_value)
      access_token.expires_in.should eq(expires_in)
      access_token.refresh_token.should eq(refresh_token)
      access_token.scope.should eq(scope)
      access_token.mac_algorithm.should eq(mac_algorithm)
      access_token.mac_key.should eq(mac_key)
    end

    it "builds with null refresh token" do
      json = %({
        "token_type": "Mac",
        "access_token":"WRN01OBN1gme8HxeRL5yJ8w05PjCvt-2vXOIle43w9s",
        "expires_in":899,
        "refresh_token":null,
        "mac_algorithm":"hmac-sha-256",
        "mac_key":"N-ATggO2ywqylWgIi3QZn40jWJmL2f9h6ZOGd3jqcxU"
        })
      access_token = AccessToken.from_json(json)
      access_token = access_token.as(Mac)
      access_token.refresh_token.should be_nil
    end

    it "dumps to json" do
      token = Mac.new("access token", 3600, "mac algorithm", "mac key", "refresh token", "scope")
      token2 = AccessToken.from_json(token.to_json)
      token2.should eq(token)
    end

    it "authenticates request" do
      headers = HTTP::Headers.new
      headers["Host"] = "localhost:4000"

      token = Mac.new("3n2-YaAzH67YH9UJ-9CnJ_PS-vSy1MRLM-q7TZknPw", 3600, "hmac-sha-256", "i-pt1Lir-yAfUdXbt-AXM1gMupK7vDiOK1SZGWkASDc")
      request = HTTP::Request.new "GET", "/some/resource.json", headers
      token.authenticate request, false
      auth = request.headers["Authorization"]
      (auth =~ /MAC id=".+?", nonce=".+?", ts=".+?", mac=".+?"/).should be_truthy
    end

    it "computes signature" do
      mac = Mac.signature 1, "0:1234", "GET", "/resource.json", "localhost", "4000", "", "hmac-sha-256", "i-pt1Lir-yAfUdXbt-AXM1gMupK7vDiOK1SZGWkASDc"
      mac.should eq("21vVRFACz5NrO+zlVfFuxTjTx5Wb0qBMfKelMTtujpE=")
    end
  end
end
