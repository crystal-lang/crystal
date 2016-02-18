require "spec"
require "html"

describe "HTML" do
  describe ".escape" do
    it "does not change a safe string" do
      str = HTML.escape("safe_string")

      str.should eq("safe_string")
    end

    it "escapes dangerous characters from a string" do
      str = HTML.escape("< & >")

      str.should eq("&lt; &amp; &gt;")
    end

    it "escapes javascript exemple from a string" do
      str = HTML.escape("<script>alert('You are being hacked')</script>")

      str.should eq("&lt;script&gt;alert&#40;&#39;You are being hacked&#39;&#41;&lt;/script&gt;")
    end

    it "escapes nonbreakable space but not normal space" do
      str = HTML.escape("nbsp space ")

      str.should eq("nbsp&nbsp;space ")
    end
  end
end
