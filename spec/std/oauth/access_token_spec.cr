require "spec"
require "oauth"

describe OAuth::AccessToken do
  it "creates from response body" do
    access_token = OAuth::AccessToken.from_response("oauth_token=1234-nyi1G37179bVdYNZGZqKQEdO&oauth_token_secret=f7T6ibH25q4qkVTAUN&user_id=1234&screen_name=someuser")
    expect(access_token.token).to eq("1234-nyi1G37179bVdYNZGZqKQEdO")
    expect(access_token.secret).to eq("f7T6ibH25q4qkVTAUN")
    expect(access_token.extra["user_id"]).to eq("1234")
    expect(access_token.extra["screen_name"]).to eq("someuser")
  end
end
