require "spec"
require "uri/json"

describe "URI" do
  describe "serializes" do
    it "#to_json" do
      URI.parse("https://example.com").to_json.should eq %q("https://example.com")
    end

    it "from_json_object_key?" do
      URI.from_json_object_key?("https://example.com").should eq(URI.parse("https://example.com"))
    end
  end
end
