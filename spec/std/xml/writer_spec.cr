require "spec"
require "xml"

private def assert_written(expected)
  io = IO::Memory.new
  writer = XML::Writer.new(io)
  with writer yield writer
  writer.flush
  io.rewind
  io.to_s.should eq(expected)
end

describe XML::Writer do
  it "writes document" do
    assert_written(%[<?xml version=\"1.0\"?>\n\n]) do
      document { }
    end
  end

  it "writes element" do
    assert_written(%[<?xml version="1.0"?>\n<foo/>\n]) do
      document do
        element("foo") { }
      end
    end
  end

  it "writes nested element" do
    assert_written(%[<?xml version="1.0"?>\n<foo><bar/></foo>\n]) do
      document do
        element("foo") do
          element("bar") { }
        end
      end
    end
  end

  it "writes element with namspace" do
    assert_written(%[<?xml version="1.0"?>\n<x:foo id="1" xmlns:x="http://foo.com"/>\n]) do
      document do
        element("x", "foo", "http://foo.com", id: 1) { }
      end
    end
  end

  it "writes element with namspace, without block" do
    assert_written(%[<?xml version="1.0"?>\n<x:foo id="1" xmlns:x="http://foo.com"/>\n]) do
      document do
        element("x", "foo", "http://foo.com", id: 1)
      end
    end
  end

  it "writes attribute" do
    assert_written(%[<?xml version="1.0"?>\n<foo id="1"/>\n]) do
      document do
        element("foo") do
          attribute("id", 1)
        end
      end
    end
  end

  it "writes attribute with namespace" do
    assert_written(%[<?xml version="1.0"?>\n<foo x:id="1" xmlns:x="http://ww.foo.com"/>\n]) do
      document do
        element("foo") do
          attribute("x", "id", "http://ww.foo.com", 1)
        end
      end
    end
  end

  it "writes text" do
    assert_written(%[<?xml version="1.0"?>\n<foo>1 &lt; 2</foo>\n]) do
      document do
        element("foo") do
          text "1 < 2"
        end
      end
    end
  end

  it "sets indent with string" do
    assert_written("<?xml version=\"1.0\"?>\n<foo>\n\t<bar/>\n</foo>\n") do |writer|
      writer.indent = "\t"
      document do
        element("foo") do
          element("bar")
        end
      end
    end
  end

  it "sets indent with count" do
    assert_written("<?xml version=\"1.0\"?>\n<foo>\n  <bar/>\n</foo>\n") do |writer|
      writer.indent = 2
      document do
        element("foo") do
          element("bar")
        end
      end
    end
  end

  it "sets quote char" do
    assert_written("<?xml version='1.0'?>\n<foo id='1'/>\n") do |writer|
      writer.quote_char = '\''
      document do
        element("foo") do
          attribute("id", 1)
        end
      end
    end
  end

  it "writes element with attributes as named tuple" do
    assert_written(%[<?xml version="1.0"?>\n<foo id="1" name="foo"/>\n]) do |writer|
      document do
        element("foo", id: 1, name: "foo")
      end
    end
  end

  it "writes element with attributes as named tuple, nesting" do
    assert_written(%[<?xml version="1.0"?>\n<foo id="1" name="foo" baz="2"/>\n]) do |writer|
      document do
        element("foo", id: 1, name: "foo") do
          attribute "baz", 2
        end
      end
    end
  end

  it "writes element with attributes as hash" do
    assert_written(%[<?xml version="1.0"?>\n<foo id="1" name="foo"/>\n]) do |writer|
      document do
        element("foo", {"id" => 1, "name" => "foo"})
      end
    end
  end

  it "writes element with attributes as hash, nesting" do
    assert_written(%[<?xml version="1.0"?>\n<foo id="1" name="foo" baz="2"/>\n]) do |writer|
      document do
        element("foo", {"id" => 1, "name" => "foo"}) do
          attribute "baz", 2
        end
      end
    end
  end

  it "writes cdata" do
    assert_written(%{<?xml version="1.0"?>\n<foo><![CDATA[hello]]></foo>\n}) do |writer|
      document do
        element("foo") do
          cdata("hello")
        end
      end
    end
  end

  it "writes cdata with block" do
    assert_written(%{<?xml version="1.0"?>\n<foo><![CDATA[hello]]></foo>\n}) do |writer|
      document do
        element("foo") do
          cdata do
            text "hello"
          end
        end
      end
    end
  end

  it "writes comment" do
    assert_written(%{<?xml version="1.0"?>\n<foo><!--hello--></foo>\n}) do |writer|
      document do
        element("foo") do
          comment("hello")
        end
      end
    end
  end

  it "writes comment with block" do
    assert_written(%{<?xml version="1.0"?>\n<foo><!--hello--></foo>\n}) do |writer|
      document do
        element("foo") do
          comment do
            text "hello"
          end
        end
      end
    end
  end

  it "writes DTD" do
    assert_written(%{<?xml version="1.0"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" [subset]>\n}) do |writer|
      document do
        dtd "html", "-//W3C//DTD XHTML 1.0 Transitional//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd", "subset"
      end
    end
  end

  it "writes DTD with block" do
    assert_written(%{<?xml version="1.0"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" [subset]>\n}) do |writer|
      document do
        dtd "html", "-//W3C//DTD XHTML 1.0 Transitional//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" do
          text "subset"
        end
      end
    end
  end

  it "writes namespace" do
    assert_written(%{<?xml version="1.0"?>\n<foo x:xmlns="http://foo.com"/>\n}) do |writer|
      document do
        element("foo") do
          namespace "x", "http://foo.com"
        end
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
end
