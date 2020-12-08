require "spec"
require "xml"

describe XML do
  it "parses" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      XML
    )
    doc.document.should eq(doc)
    doc.name.should eq("document")
    doc.attributes.empty?.should be_true
    doc.namespace.should be_nil

    people = doc.root.not_nil!
    people.name.should eq("people")
    people.type.should eq(XML::Node::Type::ELEMENT_NODE)

    people.attributes.empty?.should be_true

    children = doc.children
    children.size.should eq(1)
    children.empty?.should be_false

    people = children[0]
    people.name.should eq("people")

    people.document.should eq(doc)

    children = people.children
    children.size.should eq(3)

    text = children[0]
    text.name.should eq("text")
    text.content.should eq("\n  ")

    person = children[1]
    person.name.should eq("person")

    text = children[2]
    text.content.should eq("\n")

    attrs = person.attributes
    attrs.empty?.should be_false
    attrs.size.should eq(2)

    attr = attrs[0]
    attr.name.should eq("id")
    attr.content.should eq("1")
    attr.text.should eq("1")
    attr.inner_text.should eq("1")

    attr = attrs[1]
    attr.name.should eq("id2")
    attr.content.should eq("2")

    attrs["id"].content.should eq("1")
    attrs["id2"].content.should eq("2")

    attrs["id3"]?.should be_nil
    expect_raises(KeyError) { attrs["id3"] }

    person["id"].should eq("1")
    person["id2"].should eq("2")
    person["id3"]?.should be_nil
    expect_raises(KeyError) { person["id3"] }

    name = person.children.find { |node| node.name == "name" }.not_nil!
    name.content.should eq("John")

    name.parent.should eq(person)
  end

  it "parses from io" do
    io = IO::Memory.new(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      XML
    )

    doc = XML.parse(io)
    doc.document.should eq(doc)
    doc.name.should eq("document")

    people = doc.children.find { |node| node.name == "people" }.not_nil!
    person = people.children.find { |node| node.name == "person" }.not_nil!
    person["id"].should eq("1")
  end

  it "raises exception on empty string" do
    expect_raises XML::Error, "Document is empty" do
      XML.parse("")
    end
  end

  it "does to_s" do
    string = <<-XML
      <?xml version='1.0' encoding='UTF-8'?>\
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      XML

    doc = XML.parse(string)
    doc.to_s.strip.should eq(<<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      XML
    )
  end

  it "navigates in tree" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" />
        <person id="2" />
      </people>
      XML
    )

    people = doc.first_element_child.not_nil!
    people.name.should eq("people")

    person = people.first_element_child.not_nil!
    person.name.should eq("person")
    person["id"].should eq("1")

    text = person.next.not_nil!
    text.content.should eq("\n  ")

    text.previous.should eq(person)
    text.previous_sibling.should eq(person)

    person.next_sibling.should eq(text)

    person2 = text.next.not_nil!
    person2.name.should eq("person")
    person2["id"].should eq("2")

    person.next_element.should eq(person2)
    person2.previous_element.should eq(person)
  end

  it "handles errors" do
    xml = XML.parse(%(<people></foo>))
    xml.root.not_nil!.name.should eq("people")
    errors = xml.errors.not_nil!
    errors.size.should eq(1)

    errors[0].message.should eq("Opening and ending tag mismatch: people line 1 and foo")
    errors[0].line_number.should eq(1)
    errors[0].to_s.should eq("Opening and ending tag mismatch: people line 1 and foo")
  end

  it "gets root namespaces scopes" do
    doc = XML.parse(<<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/">
      </feed>
      XML
    )
    namespaces = doc.root.not_nil!.namespace_scopes

    namespaces.size.should eq(2)
    namespaces[0].href.should eq("http://www.w3.org/2005/Atom")
    namespaces[0].prefix.should be_nil
    namespaces[1].href.should eq("http://a9.com/-/spec/opensearchrss/1.0/")
    namespaces[1].prefix.should eq("openSearch")
  end

  it "returns empty array if no namespaces scopes exists" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <name>John</name>
      XML
    )
    namespaces = doc.root.not_nil!.namespace_scopes

    namespaces.size.should eq(0)
  end

  it "gets root namespaces as hash" do
    doc = XML.parse(<<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/">
      </feed>
      XML
    )
    namespaces = doc.root.not_nil!.namespaces
    namespaces.should eq({
      "xmlns"          => "http://www.w3.org/2005/Atom",
      "xmlns:openSearch": "http://a9.com/-/spec/opensearchrss/1.0/",
    })
  end

  it "reads big xml file (#1455)" do
    content = "." * 20_000
    string = %(<?xml version="1.0"?><root>#{content}</root>)
    parsed = XML.parse(IO::Memory.new(string))
    parsed.root.not_nil!.children[0].text.should eq(content)
  end

  it "sets node text/content" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <name>John</name>
      XML
    )
    root = doc.root.not_nil!
    root.text = "Peter"
    root.text.should eq("Peter")

    root.content = "Foo 👌"
    root.content.should eq("Foo 👌")
  end

  it "doesn't set invalid node content" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <name>John</name>
      XML
    )
    root = doc.root.not_nil!
    expect_raises(Exception, "Cannot escape") do
      root.content = "\0"
    end
  end

  it "escapes content" do
    doc = XML.parse(<<-XML)
      <?xml version='1.0' encoding='UTF-8'?>
      <name>John</name>
      XML

    root = doc.root.not_nil!
    root.text = "<foo>"
    root.text.should eq("<foo>")

    root.to_xml.should eq(%(<name>&lt;foo&gt;</name>))
  end

  it "escapes content HTML fragment" do
    doc = XML.parse_html(<<-XML, XML::HTMLParserOptions.default | XML::HTMLParserOptions::NOIMPLIED | XML::HTMLParserOptions::NODEFDTD)
      <p>foo</p>
      XML

    node = doc.children.first
    node.text = "<foo>"
    node.text.should eq("<foo>")

    node.to_xml.should eq(%(<p>&lt;foo&gt;</p>))
  end

  it "gets empty content" do
    doc = XML.parse("<foo/>")
    doc.children.first.content.should eq("")
  end

  it "sets node name" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <name>John</name>
      XML
    )
    root = doc.root.not_nil!
    root.name = "last-name"
    root.name.should eq("last-name")
  end

  it "doesn't set invalid node name" do
    doc = XML.parse(<<-XML
      <?xml version='1.0' encoding='UTF-8'?>
      <name>John</name>
      XML
    )
    root = doc.root.not_nil!

    expect_raises(XML::Error, "Invalid node name") do
      root.name = " foo bar"
    end

    expect_raises(XML::Error, "Invalid node name") do
      root.name = "foo bar"
    end

    expect_raises(XML::Error, "Invalid node name") do
      root.name = "1foo"
    end

    expect_raises(XML::Error, "Invalid node name") do
      root.name = "\0foo"
    end
  end

  it "gets encoding" do
    doc = XML.parse(<<-XML
        <?xml version='1.0' encoding='UTF-8'?>
        <people>
        </people>
        XML
    )
    doc.encoding.should eq("UTF-8")
  end

  it "gets encoding when nil" do
    doc = XML.parse(<<-XML
        <?xml version='1.0'>
        <people>
        </people>
        XML
    )
    doc.encoding.should be_nil
  end

  it "gets version" do
    doc = XML.parse(<<-XML
        <?xml version='1.0' encoding='UTF-8'?>
        <people>
        </people>
        XML
    )
    doc.version.should eq("1.0")
  end

  it "unlinks nodes" do
    xml = <<-XML
        <person id="1">
          <firstname>Jane</firstname>
          <lastname>Doe</lastname>
        </person>
        XML
    document = XML.parse(xml)

    node = document.xpath_node("//lastname").not_nil!
    node.unlink

    document.xpath_node("//lastname").should eq(nil)
  end

  it "does to_s with correct encoding (#2319)" do
    xml_str = <<-XML
    <?xml version='1.0' encoding='UTF-8'?>
    <person>
      <name>たろう</name>
    </person>
    XML

    doc = XML.parse(xml_str)
    doc.root.to_s.should eq("<person>\n  <name>たろう</name>\n</person>")
  end

  it "sets an attribute" do
    doc = XML.parse(%{<foo />})
    root = doc.root.not_nil!

    root["bar"] = "baz"
    root["bar"].should eq("baz")
    root.to_s.should eq(%{<foo bar="baz"/>})
  end

  it "changes an attribute" do
    doc = XML.parse(%{<foo bar="baz"></foo>})
    root = doc.root.not_nil!

    root["bar"] = "baz"
    root["bar"].should eq("baz")
    root.to_s.should eq(%{<foo bar="baz"/>})

    root["bar"] = 1
    root["bar"].should eq("1")
  end

  it "deletes an attribute" do
    doc = XML.parse(%{<foo bar="baz"></foo>})
    root = doc.root.not_nil!

    res = root.delete("bar")
    root["bar"]?.should be_nil
    root.to_s.should eq(%{<foo/>})
    res.should eq "baz"

    res = root.delete("biz")
    res.should be_nil
  end

  it "shows content when inspecting attribute" do
    doc = XML.parse(%{<foo bar="baz"></foo>})
    attr = doc.root.not_nil!.attributes.first
    attr.inspect.should contain(%(content="baz"))
  end

  it ".build" do
    XML.build do |builder|
      builder.element "foo" { }
    end.should eq %[<?xml version="1.0"?>\n<foo/>\n]
  end

  describe ".build_fragment" do
    it "builds fragment without XML declaration" do
      XML.build_fragment do |builder|
        builder.element "foo" { }
      end.should eq %[<foo/>\n]
    end

    it "closes open elements" do
      XML.build_fragment do |builder|
        builder.start_element "foo"
        builder.start_element "bar"
      end.should eq %[<foo><bar/></foo>\n]
    end
  end
end
