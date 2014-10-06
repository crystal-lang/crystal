require "spec"
require "oauth2"

class OAuth2::AccessToken
  describe Bearer do
    it "builds from json" do
      token_value = "some token value"
      token_type = "Bearer"
      expires_in = 3600
      refresh_token = "some refresh token"
      json = %({
        "access_token" : "#{token_value}",
        "token_type" : "#{token_type}",
        "expires_in" : #{expires_in},
        "refresh_token" : "#{refresh_token}"
        })

      access_token = AccessToken.from_json(json)
      access_token = access_token as Bearer
      access_token.token_type.should eq("Bearer")
      access_token.access_token.should eq(token_value)
      access_token.expires_in.should eq(expires_in)
      access_token.refresh_token.should eq(refresh_token)
    end

    it "dumps to json" do
      token = Bearer.new("access token", 3600, "refresh token")
      token2 = AccessToken.from_json(token.to_json)
      token2.should eq(token)
    end

    it "authenticates request" do
      token = Bearer.new("access token", 3600, "refresh token")
      request = HTTP::Request.new "GET", "/"
      token.authenticate request
      request.headers["Authorization"].should eq("Bearer access token")
    end
  end

  describe Mac do
    it "builds from json" do
      mac_algorithm = "hmac-sha-256"
      expires_in = 3600
      mac_key = "secret key"
      refresh_token = "some refresh token"
      token_value = "some token value"
      json = %({
          "token_type": "mac",
          "mac_algorithm": "#{mac_algorithm}",
          "expires_in": #{expires_in},
          "mac_key": "#{mac_key}",
          "refresh_token":"#{refresh_token}",
          "access_token":"#{token_value}"
        })

      access_token = AccessToken.from_json(json)
      access_token = access_token as Mac
      access_token.token_type.should eq("Mac")
      access_token.access_token.should eq(token_value)
      access_token.expires_in.should eq(expires_in)
      access_token.refresh_token.should eq(refresh_token)
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
      access_token = access_token as Mac
      access_token.refresh_token.should be_nil
    end

    it "dumps to json" do
      token = Mac.new("access token", 3600, "refresh token", "mac algorithm", "mac key")
      token2 = AccessToken.from_json(token.to_json)
      token2.should eq(token)
    end
  end
end
