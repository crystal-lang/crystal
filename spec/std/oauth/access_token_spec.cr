require "spec"
require "oauth"

describe OAuth::AccessToken do
  it "creates from response body" do
    access_token = OAuth::AccessToken.from_response("oauth_token=1234-nyi1G37179bVdYNZGZqKQEdO&oauth_token_secret=f7T6ibH25q4qkVTAUN&user_id=1234&screen_name=someuser")
    access_token.token.should eq("1234-nyi1G37179bVdYNZGZqKQEdO")
    access_token.secret.should eq("f7T6ibH25q4qkVTAUN")
    access_token.extra["user_id"].should eq("1234")
    access_token.extra["screen_name"].should eq("someuser")
  end
end
