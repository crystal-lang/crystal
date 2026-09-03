require "../spec_helper"
require "mime/media_type"
require "spec/helpers/string"

private def parse(string)
  type = MIME::MediaType.parse(string)

  {type.media_type, type.@params}
end

private def assert_format(string, format = string, file = __FILE__, line = __LINE__)
  assert_prints MIME::MediaType.parse(string).to_s, format, file: file, line: line
end

describe MIME::MediaType do
  describe ".new" do
    it "create new instance" do
      media_type = MIME::MediaType.new("foo/bar", {"param" => "value"})
      media_type.media_type.should eq "foo/bar"
      media_type["param"].should eq "value"
    end

    it "raises for invalid parameter name" do
      expect_raises(MIME::Error, %q(Invalid parameter name "ß")) do
        MIME::MediaType.new("foo/bar", {"param" => "value", "ß" => "invalid"})
      end
    end
  end

  describe ".parse" do
    it "parses media type" do
      MIME::MediaType.parse("text/html; charset=utf-8").media_type.should eq "text/html"
    end

    it "parses params" do
      parse("text/html; charset=utf-8").should eq({"text/html", {"charset" => "utf-8"}})

      parse("text/html; charset=us-ascii").should eq({"text/html", {"charset" => "us-ascii"}})

      parse("text/html; foo = bar; bar= foo ;").should eq({"text/html", {"foo" => "bar", "bar" => "foo", "charset" => "utf-8"}})

      parse(%(form-data; name="foo")).should eq({"form-data", {"name" => "foo"}})
      parse(%(form-data; name ="foo")).should eq({"form-data", {"name" => "foo"}})
      parse(%(form-data; name= "foo")).should eq({"form-data", {"name" => "foo"}})

      parse(%( form-data ; name=foo)).should eq({"form-data", {"name" => "foo"}})

      parse(%(FORM-DATA;name="foo")).should eq({"form-data", {"name" => "foo"}})

      parse(%( FORM-DATA ; name="foo")).should eq({"form-data", {"name" => "foo"}})

      expect_raises(MIME::Error, "Missing media type") { parse("") }
      expect_raises(MIME::Error, "Missing media type") { parse(" ") }
      expect_raises(MIME::Error, "Missing media type") { parse(";") }
      expect_raises(MIME::Error, "Missing media type") { parse(" ;") }

      expect_raises(MIME::Error, "Missing attribute name at 10") { parse("form-data;=foo") }
      expect_raises(MIME::Error, "Missing attribute name at ") { parse("form-data; =foo") }
      expect_raises(MIME::Error, "Missing attribute value") { parse("form-data;foo") }

      parse(%(form-data; key=value;  blah="value";name="foo" )).should eq({"form-data", {"key" => "value", "blah" => "value", "name" => "foo"}})

      expect_raises(MIME::Error, "Duplicate key 'key' at 15") { parse(%(foo; key=val1; key=the-key-appears-again-which-is-bogus)) }

      parse(%(FORM-DATA;NAMe="foo")).should eq({"form-data", {"name" => "foo"}})

      parse(%(message/external-body; access-type=URL; URL*0="ftp://";URL*1="cs.utk.edu/pub/moore/bulk-mailer/bulk-mailer.tar")).should eq({
        "message/external-body",
        {"access-type" => "URL", "url" => "ftp://cs.utk.edu/pub/moore/bulk-mailer/bulk-mailer.tar"},
      })

      # Tests from http://greenbytes.de/tech/tc2231/

      # attonly
      parse(%(attachment)).should eq({"attachment", {} of String => String})
      # attonlyucase
      parse(%(ATTACHMENT)).should eq({"attachment", {} of String => String})
      # attwithasciifilename
      parse(%(attachment; filename="foo.html")).should eq({"attachment", {"filename" => "foo.html"}})
      # attwithasciifilename25
      parse(%(attachment; filename="0000000000111111111122222")).should eq({"attachment", {"filename" => "0000000000111111111122222"}})
      # attwithasciifilename35
      parse(%(attachment; filename="00000000001111111111222222222233333")).should eq({"attachment", {"filename" => "00000000001111111111222222222233333"}})
      # attwithasciifnescapedchar
      parse(%(attachment; filename="f\\oo.html")).should eq({"attachment", {"filename" => "f\\oo.html"}})
      # attwithasciifnescapedquote
      parse(%(attachment; filename="\\"quoting\\" tested.html")).should eq({"attachment", {"filename" => %("quoting" tested.html)}})
      # attwithquotedsemicolon
      parse(%(attachment; filename="Here's a semicolon;.html")).should eq({"attachment", {"filename" => "Here's a semicolon;.html"}})
      # attwithfilenameandextparam
      parse(%(attachment; foo="bar"; filename="foo.html")).should eq({"attachment", {"foo" => "bar", "filename" => "foo.html"}})
      # attwithfilenameandextparamescaped
      parse(%(attachment; foo="\\"\\\\";filename="foo.html")).should eq({"attachment", {"foo" => %("\\), "filename" => "foo.html"}})
      # attwithasciifilenameucase
      parse(%(attachment; FILENAME="foo.html")).should eq({"attachment", {"filename" => "foo.html"}})
      # attwithasciifilenamenq
      parse(%(attachment; filename=foo.html)).should eq({"attachment", {"filename" => "foo.html"}})
      # attwithasciifilenamenqs
      parse(%(attachment; filename=foo.html ;)).should eq({"attachment", {"filename" => "foo.html"}})
      # attwithfntokensq
      parse(%(attachment; filename='foo.html')).should eq({"attachment", {"filename" => "'foo.html'"}})
      # attwithisofnplain
      parse(%(attachment; filename="foo-ä.html")).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attwithutf8fnplain
      parse(%(attachment; filename="foo-Ã¤.html")).should eq({"attachment", {"filename" => "foo-Ã¤.html"}})
      # attwithfnrawpctenca
      parse(%(attachment; filename="foo-%41.html")).should eq({"attachment", {"filename" => "foo-%41.html"}})
      # attwithfnusingpct
      parse(%(attachment; filename="50%.html")).should eq({"attachment", {"filename" => "50%.html"}})
      # attwithfnrawpctencaq
      parse(%(attachment; filename="foo-%\\41.html")).should eq({"attachment", {"filename" => "foo-%\\41.html"}})
      # attwithnamepct
      parse(%(attachment; name="foo-%41.html")).should eq({"attachment", {"name" => "foo-%41.html"}})
      # attwithfilenamepctandiso
      parse(%(attachment; name="ä-%41.html")).should eq({"attachment", {"name" => "ä-%41.html"}})
      # attwithfnrawpctenclong
      parse(%(attachment; filename="foo-%c3%a4-%e2%82%ac.html")).should eq({"attachment", {"filename" => "foo-%c3%a4-%e2%82%ac.html"}})
      # attwithasciifilenamews1
      parse(%(attachment; filename ="foo.html")).should eq({"attachment", {"filename" => "foo.html"}})
      # attmissingdisposition
      expect_raises(MIME::Error, "Invalid character '=' at 8") { parse(%(filename=foo.html)) }
      # attmissingdisposition2
      expect_raises(MIME::Error, "Invalid character '=' at 1") { parse(%(x=y; filename=foo.html)) }
      # attmissingdisposition3
      expect_raises(MIME::Error, "Invalid character '\"' at 0") { parse(%("foo; filename=bar;baz"; filename=qux)) }
      # attmissingdisposition4
      expect_raises(MIME::Error, "Invalid character '=' at 8") { parse(%(filename=foo.html, filename=bar.html)) }
      # emptydisposition
      expect_raises(MIME::Error, "Missing media type") { parse(%(; filename=foo.html)) }
      # doublecolon
      expect_raises(MIME::Error, "Invalid character ':' at 0") { parse(%(: inline; attachment; filename=foo.html)) }
      # attandinline
      expect_raises(MIME::Error, "Invalid ';' at 18, expecting '='") { parse(%(inline; attachment; filename=foo.html)) }
      # attandinline2
      expect_raises(MIME::Error, "Invalid ';' at 18, expecting '='") { parse(%(attachment; inline; filename=foo.html)) }
      # attbrokenquotedfn
      expect_raises(MIME::Error, "Invalid character '.' at 31, expecting ';'") { parse(%(attachment; filename="foo.html".txt)) }
      # attbrokenquotedfn2
      expect_raises(MIME::Error, "Unclosed quote at 25") { parse(%(attachment; filename="bar)) }
      # attbrokenquotedfn3
      expect_raises(MIME::Error, "Unexpected '\"' at 24") { parse(%(attachment; filename=foo"bar;baz"qux)) }
      # attmultinstances
      expect_raises(MIME::Error, "Duplicate key 'filename' at 43") { parse(%(attachment; filename=foo.html, attachment; filename=bar.html)) }
      # attmissingdelim
      expect_raises(MIME::Error, "Unexpected '=' at 28") { parse(%(attachment; foo=foo filename=bar)) }
      # attmissingdelim2
      expect_raises(MIME::Error, "Unexpected '=' at 28") { parse(%(attachment; filename=bar foo=foo)) }
      # attmissingdelim3
      expect_raises(MIME::Error, "Invalid character '=' at 19") { parse(%(attachment filename=bar)) }
      # attreversed
      expect_raises(MIME::Error, "Invalid character '=' at 8") { parse(%(filename=foo.html; attachment)) }
      # attconfusedparam
      parse(%(attachment; xfilename=foo.html)).should eq({"attachment", {"xfilename" => "foo.html"}})
      # attcdate
      parse(%(attachment; creation-date="Wed, 12 Feb 1997 16:29:51 -0500")).should eq({"attachment", {"creation-date" => "Wed, 12 Feb 1997 16:29:51 -0500"}})
      # attmdate
      parse(%(attachment; modification-date="Wed, 12 Feb 1997 16:29:51 -0500")).should eq({"attachment", {"modification-date" => "Wed, 12 Feb 1997 16:29:51 -0500"}})
      # dispext
      parse("foobar").should eq({"foobar", {} of String => String})
      # dispextbadfn
      parse(%(attachment; example="filename=example.txt")).should eq({"attachment", {"example" => "filename=example.txt"}})
      # # attwithfn2231utf8
      parse(%(attachment; filename*=UTF-8''foo-%c3%a4-%e2%82%ac.html)).should eq({"attachment", {"filename" => "foo-ä-€.html"}})
      # attwithfn2231noc
      parse(%(attachment; filename*=''foo-%c3%a4-%e2%82%ac.html)).should eq({"attachment", {} of String => String})
      # attwithfn2231utf8comp
      parse(%(attachment; filename*=UTF-8''foo-a%cc%88.html)).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attwithfn2231ws2
      parse(%(attachment; filename*= UTF-8''foo-%c3%a4.html)).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attwithfn2231ws3
      parse(%(attachment; filename* =UTF-8''foo-%c3%a4.html)).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attwithfn2231quot
      parse(%(attachment; filename*="UTF-8''foo-%c3%a4.html")).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attwithfn2231quot2
      parse(%(attachment; filename*="foo%20bar.html")).should eq({"attachment", {} of String => String})
      # attwithfn2231singleqmissing
      parse(%(attachment; filename*=UTF-8'foo-%c3%a4.html)).should eq({"attachment", {} of String => String})
      # attwithfn2231nbadpct1
      parse(%(attachment; filename*=UTF-8''foo%)).should eq({"attachment", {} of String => String})
      # attwithfn2231nbadpct2
      parse(%(attachment; filename*=UTF-8''f%oo.html)).should eq({"attachment", {} of String => String})
      # attwithfn2231dpct
      parse(%(attachment; filename*=UTF-8''A-%2541.html)).should eq({"attachment", {"filename" => "A-%41.html"}})
      # attfncont
      parse(%(attachment; filename*0="foo."; filename*1="html")).should eq({"attachment", {"filename" => "foo.html"}})

      expect_raises(MIME::Error, "Duplicate key 'foo *0' at 25") { parse(%(attachment; foo*0="foo"; foo *0="bar")) }
      expect_raises(MIME::Error, "Duplicate key 'foo* 0' at 25") { parse(%(attachment; foo*0="foo"; foo* 0="bar")) }
      expect_raises(MIME::Error, "Invalid key 'foo*foo' at 12") { parse(%(attachment; foo*foo=foo)) }

      # attfncontenc
      parse(%(attachment; filename*0*=UTF-8''foo-%c3%a4; filename*1=".html")).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attfncontlz
      parse(%(attachment; filename*0="foo"; filename*01="bar")).should eq({"attachment", {"filename" => "foo"}})
      # attfncontnc
      parse(%(attachment; filename*0="foo"; filename*2="bar")).should eq({"attachment", {"filename" => "foo"}})
      # attfnconts1
      parse(%(attachment; filename*1="foo."; filename*2="html")).should eq({"attachment", {} of String => String})
      # attfncontord
      parse(%(attachment; filename*1="bar"; filename*0="foo")).should eq({"attachment", {"filename" => "foobar"}})
      # attfnboth
      parse(%(attachment; filename="foo-ae.html"; filename*=UTF-8''foo-%c3%a4.html)).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attfnboth2
      parse(%(attachment; filename*=UTF-8''foo-%c3%a4.html; filename="foo-ae.html")).should eq({"attachment", {"filename" => "foo-ä.html"}})
      # attnewandfn
      parse(%(attachment; foobar=x; filename="foo.html")).should eq({"attachment", {"foobar" => "x", "filename" => "foo.html"}})

      # Browsers also just send UTF-8 directly without RFC 2231,
      # at least when the source page is served with UTF-8.
      parse(%(form-data; firstname="Брэд"; lastname="Фицпатрик")).should eq({"form-data", {"firstname" => "Брэд", "lastname" => "Фицпатрик"}})

      # Empty string used to be mishandled.
      parse(%(foo; bar="")).should eq({"foo", {"bar" => ""}})

      # Microsoft browsers in intranet mode do not think they need to escape \ in file name.
      parse(%(form-data; name="file"; filename="C:\\dev\\go\\robots.txt")).should eq({"form-data", {"name" => "file", "filename" => "C:\\dev\\go\\robots.txt"}})

      # Skip whitespace after =
      parse(%(form-data; foo= foo)).should eq({"form-data", {"foo" => "foo"}})
      parse(%(form-data; foo= " foo ")).should eq({"form-data", {"foo" => " foo "}})
    end

    {% unless flag?(:without_iconv) %}
      it "parses params with encoding" do
        # From RFC 2231:
        parse(%(application/x-stuff; title*=us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A)).should eq({"application/x-stuff", {"title" => "This is ***fun***"}})
        # attfnboth3
        parse(%(attachment; filename*0*=ISO-8859-15''euro-sign%3d%a4; filename*=ISO-8859-1''currency-sign%3d%a4)).should eq({"attachment", {"filename" => "currency-sign=¤"}})
      end
    {% end %}

    it "sets default charset to utf-8 for text media types" do
      type = MIME::MediaType.parse("text/html")
      type["charset"]?.should eq "utf-8"

      type = MIME::MediaType.parse("application/html")
      type["charset"]?.should be_nil
    end
  end

  it "#sub_type" do
    MIME::MediaType.new("text/plain").sub_type.should eq "plain"
    MIME::MediaType.new("foo").sub_type.should be_nil
  end

  it "#type" do
    MIME::MediaType.new("text/plain").type.should eq "text"
    MIME::MediaType.new("foo").type.should eq "foo"
  end

  it "#to_s" do
    assert_format "foo/bar"
    assert_format "text/plain; charset=utf-8"
    assert_format "foo/bar; foo=bar; bar=foo;", "foo/bar; foo=bar; bar=foo"
    assert_format "form-data; name=foo"
    assert_format "attachment"
    assert_format %(attachment; faa="\\"\\\\"; filename="foo.html?")
    assert_format %(attachment; filename="foo-Ã¤.html")
    assert_format %(attachment; filename=foo-%41.html)
    assert_format %(attachment; filename="\\"quoting\\" tested.html")
  end

  it "#fetch" do
    MIME::MediaType.parse("x-application/example").fetch("foo", "baz").should eq "baz"
    MIME::MediaType.parse("x-application/example; foo=bar").fetch("foo", "baz").should eq "bar"
    MIME::MediaType.parse("x-application/example").fetch("foo") { |key| key }.should eq "foo"
    MIME::MediaType.parse("x-application/example; foo=bar").fetch("foo") { |key| key }.should eq "bar"
  end

  it "#[]=" do
    mime_type = MIME::MediaType.parse("x-application/example")
    mime_type["foo"] = "bar"
    mime_type["foo"].should eq "bar"

    expect_raises(MIME::Error, "Invalid parameter name") do
      mime_type["ä"] = "foo"
    end
  end

  it "#each_parameter" do
    mime_type = MIME::MediaType.parse("x-application/example; foo=bar; bar=baz")

    arr = [] of String
    mime_type.each_parameter do |key, value|
      arr << "#{key}=#{value}"
    end
    arr.should eq ["foo=bar", "bar=baz"]

    arr = [] of String
    mime_type.each_parameter.each do |key, value|
      arr << "#{key}=#{value}"
    end
    arr.should eq ["foo=bar", "bar=baz"]
  end
end
