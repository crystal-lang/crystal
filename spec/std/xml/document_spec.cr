require "spec"
require "xml"

describe Xml::Document do
  it "parses" do
    doc = Xml.parse(%(\
      <?xml version='1.0' encoding='UTF-8'?>
      <people>
        <person id="1">
          <name>John</name>
        </person>
      </people>
      ))
    doc.should be_a(Xml::Document)
    doc.child_nodes.length.should eq(1)

    people = doc.child_nodes.first
    people.name.should eq("people")
    people.child_nodes.length.should eq(1)

    person = people.child_nodes.first
    person.name.should eq("person")
    person.child_nodes.length.should eq(1)

    name = person.child_nodes.first
    name.name.should eq("name")
  end
end
