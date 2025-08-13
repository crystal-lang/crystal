require "spec"
require "openssl"
require "http"

describe "https requests" do
  it "can fetch from google.com" do
    HTTP::Client.get("https://google.com")
  end

  it "can fetch from google.com. FQDN with trailing dot (#12777)" do
    HTTP::Client.get("https://google.com.")
  end

  it "can close request before consuming body" do
    HTTP::Client.get("https://crystal-lang.org") do
      break
    end
  end
end
