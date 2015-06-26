require "spec"
require "xml"

describe XML do
  it "parses" do
    doc = XML.parse(%(\
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      ))
    doc.document.should eq(doc)
    doc.name.should eq("document")
    doc.attributes.empty?.should be_true
    doc.namespace.should be_nil

    people = doc.root.not_nil!
    people.name.should eq("people")
    people.type.should eq(XML::Type::ELEMENT_NODE)

    people.attributes.empty?.should be_true

    children = doc.children
    children.length.should eq(1)
    children.empty?.should be_false

    people = children[0]
    people.name.should eq("people")

    people.document.should eq(doc)

    children = people.children
    children.length.should eq(3)

    text = children[0]
    text.name.should eq("text")
    text.content.should eq("\n        ")

    person = children[1]
    person.name.should eq("person")

    text = children[2]
    text.content.should eq("\n      ")

    attrs = person.attributes
    attrs.empty?.should be_false
    attrs.length.should eq(2)

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
    io = StringIO.new(%(\
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      ))

    doc = XML.parse(io)
    doc.document.should eq(doc)
    doc.name.should eq("document")

    people = doc.children.find { |node| node.name == "people" }.not_nil!
    person = people.children.find { |node| node.name == "person" }.not_nil!
    person["id"].should eq("1")
  end

  it "does to_s" do
    string = %(\
      <?xml version='1.0' encoding='UTF-8'?>\
      <people>\
        <person id="1" id2="2">\
          <name>John</name>\
        </person>\
      </people>\
      )

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
    doc = XML.parse(%(\
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" />
        <person id="2" />
      </people>
      ))

    people = doc.first_element_child.not_nil!
    people.name.should eq("people")

    person = people.first_element_child.not_nil!
    person.name.should eq("person")
    person["id"].should eq("1")

    text = person.next.not_nil!
    text.content.should eq("\n        ")

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
    expect_raises(XML::Error, "Premature end of data in tag people line 2") do
      XML.parse(%(
        <people>
        ))
    end
  end

  it "gets root namespaces scopes" do
    doc = XML.parse(%(\
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/">
      </feed>
      ))
    namespaces = doc.root.not_nil!.namespace_scopes

    namespaces.length.should eq(2)
    namespaces[0].href.should eq("http://www.w3.org/2005/Atom")
    namespaces[0].prefix.should be_nil
    namespaces[1].href.should eq("http://a9.com/-/spec/opensearchrss/1.0/")
    namespaces[1].prefix.should eq("openSearch")
  end

  it "gets root namespaces as hash" do
    doc = XML.parse(%(\
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/">
      </feed>
      ))
    namespaces = doc.root.not_nil!.namespaces
    namespaces.should eq({
      "xmlns" => "http://www.w3.org/2005/Atom",
      "xmlns:openSearch": "http://a9.com/-/spec/opensearchrss/1.0/",
    })
  end
end
