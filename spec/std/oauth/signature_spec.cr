require "spec"
require "oauth"

describe OAuth::Signature do
  describe "key" do
    it "gets when token secret is empty" do
      signature = OAuth::Signature.new "consumer_key", "consumer secret"
      signature.key.should eq("consumer%20secret&")
    end

    it "gets when token secret is not empty" do
      signature = OAuth::Signature.new "consumer_key", "consumer secret", token_shared_secret: "token secret"
      signature.key.should eq("consumer%20secret&token%20secret")
    end
  end

  describe "base string" do
    it "computes without port in host" do
      request = HTTP::Request.new "POST", "/some/path"
      request.headers["Host"] = "some.host"
      tls = false
      ts = "1234"

      signature = OAuth::Signature.new "consumer_key", "consumer secret", extra_params: {
        "oauth_callback" => "some+callback",
      }
      base_string = signature.base_string request, tls, ts, "nonce"
      base_string.should eq("POST&http%3A%2F%2Fsome.host%2Fsome%2Fpath&oauth_callback%3Dsome%252Bcallback%26oauth_consumer_key%3Dconsumer_key%26oauth_nonce%3Dnonce%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1234%26oauth_version%3D1.0")
    end

    it "computes with port in host" do
      request = HTTP::Request.new "POST", "/some/path"
      request.headers["Host"] = "some.host:5678"
      tls = false
      ts = "1234"

      signature = OAuth::Signature.new "consumer_key", "consumer secret", extra_params: {
        "oauth_callback" => "some+callback",
      }
      base_string = signature.base_string request, tls, ts, "nonce"
      base_string.should eq("POST&http%3A%2F%2Fsome.host%3A5678%2Fsome%2Fpath&oauth_callback%3Dsome%252Bcallback%26oauth_consumer_key%3Dconsumer_key%26oauth_nonce%3Dnonce%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1234%26oauth_version%3D1.0")
    end

    it "computes when TLS" do
      request = HTTP::Request.new "POST", "/some/path"
      request.headers["Host"] = "some.host"
      tls = true
      ts = "1234"

      signature = OAuth::Signature.new "consumer_key", "consumer secret", extra_params: {
        "oauth_callback" => "some+callback",
      }
      base_string = signature.base_string request, tls, ts, "nonce"
      base_string.should eq("POST&https%3A%2F%2Fsome.host%2Fsome%2Fpath&oauth_callback%3Dsome%252Bcallback%26oauth_consumer_key%3Dconsumer_key%26oauth_nonce%3Dnonce%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1234%26oauth_version%3D1.0")
    end
  end

  # https://dev.twitter.com/oauth/overview/creating-signatures
  it "does twitter sample" do
    request = HTTP::Request.new "POST", "/1/statuses/update.json?include_entities=true", body: "status=Hello%20Ladies%20%2b%20Gentlemen%2c%20a%20signed%20OAuth%20request%21"
    request.headers["Host"] = "api.twitter.com"
    request.headers["Content-type"] = "application/x-www-form-urlencoded"
    tls = true
    ts = "1318622958"
    nonce = "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"
    consumer_key = "xvz1evFS4wEEPTGEFPHBog"
    consumer_secret = "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw"
    oauth_token = "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb"
    oauth_token_secret = "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE"

    signature = OAuth::Signature.new consumer_key, consumer_secret, oauth_token: oauth_token, token_shared_secret: oauth_token_secret
    base_string = signature.base_string(request, tls, ts, nonce)
    expected_base_string = "POST&https%3A%2F%2Fapi.twitter.com%2F1%2Fstatuses%2Fupdate.json&include_entities%3Dtrue%26oauth_consumer_key%3Dxvz1evFS4wEEPTGEFPHBog%26oauth_nonce%3DkYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1318622958%26oauth_token%3D370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb%26oauth_version%3D1.0%26status%3DHello%2520Ladies%2520%252B%2520Gentlemen%252C%2520a%2520signed%2520OAuth%2520request%2521"

    base_string.should eq(expected_base_string)

    computed = signature.compute request, tls, ts, nonce
    expected_computed = "tnnArxj06cWHq44gCs1OSKk/jLY="

    computed.should eq(expected_computed)

    header = signature.authorization_header request, tls, ts, nonce
    expected_header = %(OAuth oauth_consumer_key="xvz1evFS4wEEPTGEFPHBog", oauth_signature_method="HMAC-SHA1", oauth_timestamp="1318622958", oauth_nonce="kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg", oauth_signature="tnnArxj06cWHq44gCs1OSKk%2FjLY%3D", oauth_token="370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb", oauth_version="1.0")

    header.should eq(expected_header)
  end
end
