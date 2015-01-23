require "spec"
require "html/escaped_string"

describe "HTML" do
  describe "EscapedString" do
    describe ".escape" do
      it "does not change a safe string" do
        str = HTML::EscapedString.escape("safe_string")

        str.should eq("safe_string")
      end

      it "escapes dangerous characters from a string" do
        str = HTML::EscapedString.escape("< & >")

        str.should eq("&lt; &amp; &gt;")
      end
    end
  end
end

describe "String" do
  describe "#html_escape" do
    it "escapes the string" do
      str = "< & >".html_escape

      str.should eq("&lt; &amp; &gt;")
    end
  end
end
