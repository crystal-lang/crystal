require "spec"
require "oauth"

describe OAuth::RequestToken do
  it "creates from response" do
    token = OAuth::RequestToken.from_response("oauth_token_secret=p58A6bzyGaT8PR54gM0S4ZesOVC2ManiTmwHcho8&oauth_callback_confirmed=true&oauth_token=qyprd6Pe2PbnSxUcyHcWz0VnTF8bg1rxsBbUwOpkQ6bSQEyK")
    token.secret.should eq("p58A6bzyGaT8PR54gM0S4ZesOVC2ManiTmwHcho8")
    token.token.should eq("qyprd6Pe2PbnSxUcyHcWz0VnTF8bg1rxsBbUwOpkQ6bSQEyK")
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
