require "spec"
require "oauth"

describe OAuth::RequestToken do
  it "creates from response" do
    token = OAuth::RequestToken.from_response("oauth_token_secret=p58A6bzyGaT8PR54gM0S4ZesOVC2ManiTmwHcho8&oauth_callback_confirmed=true&oauth_token=qyprd6Pe2PbnSxUcyHcWz0VnTF8bg1rxsBbUwOpkQ6bSQEyK")
    expect(token.secret).to eq("p58A6bzyGaT8PR54gM0S4ZesOVC2ManiTmwHcho8")
    expect(token.token).to eq("qyprd6Pe2PbnSxUcyHcWz0VnTF8bg1rxsBbUwOpkQ6bSQEyK")
  end
end
