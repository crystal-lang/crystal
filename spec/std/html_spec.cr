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

    it "escapes javascript example from a string" do
      str = HTML.escape("<script>alert('You are being hacked')</script>")

      str.should eq("&lt;script&gt;alert&#40;&#39;You are being hacked&#39;&#41;&lt;/script&gt;")
    end

    it "escapes nonbreakable space but not normal space" do
      str = HTML.escape("nbsp space ")

      str.should eq("nbsp&nbsp;space ")
    end
  end

  describe ".unescape" do
    it "does not change a safe string" do
      str = HTML.unescape("safe_string")

      str.should eq("safe_string")
    end

    it "unescapes dangerous characters from a string" do
      str = HTML.unescape("&lt; &amp; &gt;")

      str.should eq("< & >")
    end

    it "unescapes javascript example from a string" do
      str = HTML.unescape("&lt;script&gt;alert&#40;&#39;You are being hacked&#39;&#41;&lt;/script&gt;")

      str.should eq("<script>alert('You are being hacked')</script>")
    end

    it "unescapes decimal encoded chars" do
      str = HTML.unescape("&lt;&#104;&#101;llo world&gt;")

      str.should eq("<hello world>")
    end

    it "unescapes with invalid entities" do
      str = HTML.unescape("&&lt;&amp&gt;&quot&abcdefghijklmn")

      str.should eq("&<&amp>&quot&abcdefghijklmn")
    end

    it "unescapes hex encoded chars" do
      str = HTML.unescape("3 &#x0002B; 2 &#x0003D; 5")

      str.should eq("3 + 2 = 5")
    end

    it "unescapes &nbsp;" do
      str = HTML.unescape("nbsp&nbsp;space ")

      str.should eq("nbsp space ")
    end

    it "unescapes Char::MAX_CODEPOINT" do
      str = HTML.unescape("limit &#x10FFFF;")
      str.should eq("limit 􏿿")

      str = HTML.unescape("limit &#1114111;")
      str.should eq("limit 􏿿")
    end
  end
end
