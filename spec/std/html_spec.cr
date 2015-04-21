require "spec"
require "html"

describe "HTML" do
  describe ".escape" do
    it "does not change a safe string" do
      str = HTML.escape("safe_string")

      expect(str).to eq("safe_string")
    end

    it "escapes dangerous characters from a string" do
      str = HTML.escape("< & >")

      expect(str).to eq("&lt; &amp; &gt;")
    end
  end
end
