require "spec"
require "openssl"
require "http"

describe "https requests" do
  it "can fetch from google.com" do
    HTTP::Client.get("https://google.com")
  end

  it "can close request before consuming body" do
    HTTP::Client.get("https://crystal-lang.org") do
      break
    end
  end

  it "can fetch from IIS servers that don't shutdown gracefully" do
    HTTP::Client.post("https://login.microsoftonline.com/common/oauth2/token", form: {"hi" => "a"}).body
  end
end
