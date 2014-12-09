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
      ))
    doc.should be_a(XML::Document)
    doc.has_child_nodes?.should be_true
    doc.child_nodes.length.should eq(1)
    doc.has_attributes?.should be_false

    people = doc.child_nodes.first
    people.name.should eq("people")
    people.has_child_nodes?.should be_true
    people.child_nodes.length.should eq(1)
    people.has_attributes?.should be_false

    person = people.child_nodes.first
    person.name.should eq("person")
    person.has_child_nodes?.should be_true
    person.child_nodes.length.should eq(1)

    person.has_attributes?.should be_true
    person.attributes.length.should eq(2)
    person.attributes[0].name.should eq("id")
    person.attributes[0].value.should eq("1")
    person.attributes[1].name.should eq("id2")
    person.attributes[1].value.should eq("2")

    person.attributes["id"].should eq("1")
    person.attributes["id2"].should eq("2")

    expect_raises MissingKey, "missing attribute: id3" do
      person.attributes["id3"]
    end

    person.attributes["id"]?.should eq("1")
    person.attributes["id3"]?.should be_nil

    name = person.child_nodes.first
    name.name.should eq("name")
    name.inner_text.should eq("John")
    name.has_child_nodes?.should be_true
    name.has_attributes?.should be_false

    text = name.child_nodes[0]
    text.name.should be_nil
    text.value.should eq("John")
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
    doc.to_s.should eq(string)
  end
end
