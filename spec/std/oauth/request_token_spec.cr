require "spec"
require "oauth"

describe OAuth::RequestToken do
  describe "creating from response" do
    it "creates from a valid response" do
      token = OAuth::RequestToken.from_response("oauth_token_secret=p58A6bzyGaT8PR54gM0S4ZesOVC2ManiTmwHcho8&oauth_callback_confirmed=true&oauth_token=qyprd6Pe2PbnSxUcyHcWz0VnTF8bg1rxsBbUwOpkQ6bSQEyK")
      token.secret.should eq("p58A6bzyGaT8PR54gM0S4ZesOVC2ManiTmwHcho8")
      token.token.should eq("qyprd6Pe2PbnSxUcyHcWz0VnTF8bg1rxsBbUwOpkQ6bSQEyK")
    end

    it "raises an error when the token is missing" do
      expect_raises OAuth::Error, "Missing token" do
        OAuth::RequestToken.from_response("oauth_token_secret=foo")
      end
    end

    it "raises an error when the secret is missing" do
      expect_raises OAuth::Error, "Missing secret" do
        OAuth::RequestToken.from_response("oauth_token=foo")
      end
    end

    it "raises an error when the token AND secret are missing" do
      expect_raises OAuth::Error, "Missing token and secret" do
        OAuth::RequestToken.from_response("error=oops")
      end
    end
  end

  describe "equality" do
    it "checks token" do
      foo1 = OAuth::RequestToken.new("foo", "secret")
      foo2 = OAuth::RequestToken.new("foo", "secret")
      bar1 = OAuth::RequestToken.new("bar", "secret")
      bar2 = OAuth::RequestToken.new("bar", "secret")

      foo1.should eq(foo2)
      foo1.should_not eq(bar2)
      bar1.should_not eq(foo2)
      bar1.should eq(bar2)

      foo1.hash.should eq(foo2.hash)
      foo1.hash.should_not eq(bar2.hash)
      bar1.hash.should_not eq(foo2.hash)
      bar1.hash.should eq(bar2.hash)
    end

    it "checks secret" do
      foo1 = OAuth::RequestToken.new("token", "foo")
      foo2 = OAuth::RequestToken.new("token", "foo")
      bar1 = OAuth::RequestToken.new("token", "bar")
      bar2 = OAuth::RequestToken.new("token", "bar")

      foo1.should eq(foo2)
      foo1.should_not eq(bar2)
      bar1.should_not eq(foo2)
      bar1.should eq(bar2)

      foo1.hash.should eq(foo2.hash)
      foo1.hash.should_not eq(bar2.hash)
      bar1.hash.should_not eq(foo2.hash)
      bar1.hash.should eq(bar2.hash)
    end
  end
end
