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

    people = doc.root.not_nil! as XML::Element
    people.name.should eq("people")
    people.type.should eq(XML::Type::Element)

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

  it "handles errors" do
    expect_raises(XML::Error, "Premature end of data in tag people line 2") do
      XML.parse(%(
        <people>
        ))
    end
  end
end
