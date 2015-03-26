require "spec"
require "xml"

describe XML::Document do
  it "parses" do
    doc = XML.parse(%(\
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" id2="2">
          <name>John</name>
        </person>
      </people>
      )) as XML::Document
    doc.document.should be(doc)
    doc.name.should eq("document")
    doc.attributes.empty?.should be_true

    people = doc.root.not_nil! as XML::Element
    people.name.should eq("people")
    people.type.should eq(XML::Type::Element)

    people.attributes.empty?.should be_true

    children = doc.children as XML::NodeSet
    children.length.should eq(1)
    children.empty?.should be_false

    people = children[0] as XML::Element
    people.name.should eq("people")

    people.document.should eq(doc)
    people.document.should be(doc)

    children = people.children
    children.length.should eq(3)

    text = children[0] as XML::Text
    text.name.should eq("text")
    text.content.should eq("\n        ")

    person = children[1] as XML::Element
    person.name.should eq("person")

    text = children[2] as XML::Text
    text.content.should eq("\n      ")

    attrs = person.attributes
    attrs.empty?.should be_false
    attrs.length.should eq(2)

    attr = attrs[0] as XML::Attribute
    attr.name.should eq("id")
    attr.content.should eq("1")

    attr = attrs[1] as XML::Attribute
    attr.name.should eq("id2")
    attr.content.should eq("2")

    attrs["id"].content.should eq("1")
    attrs["id2"].content.should eq("2")

    attrs["id3"]?.should be_nil
    expect_raises(MissingKey) { attrs["id3"] }

    person["id"].should eq("1")
    person["id2"].should eq("2")
    person["id3"]?.should be_nil
    expect_raises(MissingKey) { person["id3"] }

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

    doc = XML.parse(io) as XML::Document
    doc.document.should be(doc)
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
    doc.to_s.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<people><person id=\"1\" id2=\"2\"><name>John</name></person></people>\n")
  end

  it "navigates in tree" do
    doc = XML.parse(%(\
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1" />
        <person id="2" />
      </people>
      )) as XML::Document

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
end
