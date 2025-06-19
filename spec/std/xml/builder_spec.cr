require "spec"
require "xml"
require "spec/helpers/string"

private def assert_built(expected, quote_char = nil, *, file = __FILE__, line = __LINE__, &)
  assert_prints XML.build(quote_char: quote_char) { |xml| with xml yield xml }, expected, file: file, line: line
end

describe XML::Builder do
  it "writes document" do
    assert_built(%[<?xml version="1.0"?>\n\n]) do
    end
  end

  it "writes element" do
    assert_built(%[<?xml version="1.0"?>\n<foo/>\n]) do
      element("foo") { }
    end
  end

  it "errors on invalid element names" do
    expect_raises(XML::Error, "Invalid element name: '1'") do
      XML.build do |xml|
        xml.element("1") do
        end
      end
    end

    expect_raises(XML::Error, "Invalid element name: 'a b=\"c\"'") do
      XML.build do |xml|
        xml.element("a b=\"c\"") do
        end
      end
    end
  end

  it "writes nested element" do
    assert_built(%[<?xml version="1.0"?>\n<foo><bar/></foo>\n]) do
      element("foo") do
        element("bar") { }
      end
    end
  end

  it "writes element with namespace" do
    assert_built(%[<?xml version="1.0"?>\n<x:foo id="1" xmlns:x="http://foo.com"/>\n]) do
      element("x", "foo", "http://foo.com", id: 1) { }
    end
  end

  it "writes element with namespace, without block" do
    assert_built(%[<?xml version="1.0"?>\n<x:foo id="1" xmlns:x="http://foo.com"/>\n]) do
      element("x", "foo", "http://foo.com", id: 1)
    end
  end

  it "writes attribute" do
    assert_built(%[<?xml version="1.0"?>\n<foo id="1"/>\n]) do
      element("foo") do
        attribute("id", 1)
      end
    end
  end

  it "writes attribute with namespace" do
    assert_built(%[<?xml version="1.0"?>\n<foo x:id="1" xmlns:x="http://ww.foo.com"/>\n]) do
      element("foo") do
        attribute("x", "id", "http://ww.foo.com", 1)
      end
    end
  end

  it "writes element with namespace" do
    assert_built(%[<?xml version="1.0"?>\n<foo xmlns="bar">baz</foo>\n]) do
      element(nil, "foo", "bar") do
        text "baz"
      end
    end
  end

  it "writes element with prefix" do
    assert_built(%[<?xml version="1.0"?>\n<foo:bar>baz</foo:bar>\n]) do
      element("foo", "bar", nil) do
        text "baz"
      end
    end
  end

  it "errors on invalid element name with prefix" do
    expect_raises(XML::Error, "Invalid prefix: 'foo='") do
      XML.build do |xml|
        xml.element("foo=", "bar", nil) do
          xml.text "baz"
        end
      end
    end
  end

  it "errors on invalid element name with prefix and namespace" do
    expect_raises(XML::Error, "Invalid prefix: 'foo '") do
      XML.build do |xml|
        xml.element("foo ", "bar", "ns") do
          xml.text "baz"
        end
      end
    end
  end

  it "writes text" do
    assert_built(%[<?xml version="1.0"?>\n<foo>1 &lt; 2</foo>\n]) do
      element("foo") do
        text "1 < 2"
      end
    end
  end

  it "sets indent with string" do
    assert_built("<?xml version=\"1.0\"?>\n<foo>\n\t<bar/>\n</foo>\n") do |xml|
      xml.indent = "\t"
      element("foo") do
        element("bar")
      end
    end
  end

  it "sets indent with count" do
    assert_built("<?xml version=\"1.0\"?>\n<foo>\n  <bar/>\n</foo>\n") do |xml|
      xml.indent = 2
      element("foo") do
        element("bar")
      end
    end
  end

  it "sets quote char" do
    assert_built("<?xml version='1.0'?>\n<foo id='1'/>\n", quote_char: '\'') do |xml|
      element("foo") do
        attribute("id", 1)
      end
    end
  end

  it "writes element with attributes as named tuple" do
    assert_built(%[<?xml version="1.0"?>\n<foo id="1" name="foo"/>\n]) do |xml|
      element("foo", id: 1, name: "foo")
    end
  end

  it "writes element with attributes as named tuple, nesting" do
    assert_built(%[<?xml version="1.0"?>\n<foo id="1" name="foo" baz="2"/>\n]) do |xml|
      element("foo", id: 1, name: "foo") do
        attribute "baz", 2
      end
    end
  end

  it "writes element with attributes as hash" do
    assert_built(%[<?xml version="1.0"?>\n<foo id="1" name="foo"/>\n]) do |xml|
      element("foo", {"id" => 1, "name" => "foo"})
    end
  end

  it "writes element with attributes as hash, nesting" do
    assert_built(%[<?xml version="1.0"?>\n<foo id="1" name="foo" baz="2"/>\n]) do |xml|
      element("foo", {"id" => 1, "name" => "foo"}) do
        attribute "baz", 2
      end
    end
  end

  describe "#cdata" do
    it "writes cdata" do
      assert_built(%{<?xml version="1.0"?>\n<foo><![CDATA[hello]]></foo>\n}) do |xml|
        element("foo") do
          cdata("hello")
        end
      end
    end

    it "escapes ]]> sequences" do
      assert_built(%{<?xml version="1.0"?>\n<foo><![CDATA[One]]]]><![CDATA[>Two]]]]><![CDATA[>Three]]></foo>\n}) do |xml|
        element("foo") do
          cdata("One]]>Two]]>Three")
        end
      end
    end

    it "writes cdata with block" do
      assert_built(%{<?xml version="1.0"?>\n<foo><![CDATA[hello]]></foo>\n}) do |xml|
        element("foo") do
          cdata do
            text "hello"
          end
        end
      end
    end
  end

  it "writes comment" do
    assert_built(%{<?xml version="1.0"?>\n<foo><!--hello--></foo>\n}) do |xml|
      element("foo") do
        comment("hello")
      end
    end
  end

  it "writes comment with block" do
    assert_built(%{<?xml version="1.0"?>\n<foo><!--hello--></foo>\n}) do |xml|
      element("foo") do
        comment do
          text "hello"
        end
      end
    end
  end

  it "writes DTD" do
    assert_built(%{<?xml version="1.0"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" [subset]>\n}) do |xml|
      dtd "html", "-//W3C//DTD XHTML 1.0 Transitional//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd", "subset"
    end
  end

  it "writes DTD with block" do
    assert_built(%{<?xml version="1.0"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" [subset]>\n}) do |xml|
      dtd "html", "-//W3C//DTD XHTML 1.0 Transitional//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" do
        text "subset"
      end
    end
  end

  it "writes namespace" do
    assert_built(%{<?xml version="1.0"?>\n<foo xmlns:x="http://foo.com"/>\n}) do |xml|
      element("foo") do
        namespace "x", "http://foo.com"
      end
    end
  end

  it "writes to string" do
    str = XML.build do |xml|
      xml.element("foo", id: 1) do
        xml.text "hello"
      end
    end
    str.should eq("<?xml version=\"1.0\"?>\n<foo id=\"1\">hello</foo>\n")
  end

  it "writes to IO" do
    io = IO::Memory.new
    XML.build(io) do |xml|
      xml.element("foo", id: 1) do
        xml.text "hello"
      end
    end
    io.rewind
    io.to_s.should eq("<?xml version=\"1.0\"?>\n<foo id=\"1\">hello</foo>\n")
  end

  it "errors on null byte" do
    expect_raises(XML::Error, "String cannot contain null character") do
      XML.build do |xml|
        xml.element("example", number: "1") do
          xml.text "foo\0bar"
        end
      end
    end

    expect_raises(XML::Error, "String cannot contain null character") do
      XML.build do |xml|
        xml.element("exam\0ple", number: "1") do
          xml.text "foobar"
        end
      end
    end
  end
end
