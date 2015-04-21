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
    expect(doc.document).to eq(doc)
    expect(doc.name).to eq("document")
    expect(doc.attributes.empty?).to be_true

    people = doc.root.not_nil!
    expect(people.name).to eq("people")
    expect(people.type).to eq(XML::Type::ELEMENT_NODE)

    expect(people.attributes.empty?).to be_true

    children = doc.children
    expect(children.length).to eq(1)
    expect(children.empty?).to be_false

    people = children[0]
    expect(people.name).to eq("people")

    expect(people.document).to eq(doc)

    children = people.children
    expect(children.length).to eq(3)

    text = children[0]
    expect(text.name).to eq("text")
    expect(text.content).to eq("\n        ")

    person = children[1]
    expect(person.name).to eq("person")

    text = children[2]
    expect(text.content).to eq("\n      ")

    attrs = person.attributes
    expect(attrs.empty?).to be_false
    expect(attrs.length).to eq(2)

    attr = attrs[0]
    expect(attr.name).to eq("id")
    expect(attr.content).to eq("1")
    expect(attr.text).to eq("1")
    expect(attr.inner_text).to eq("1")

    attr = attrs[1]
    expect(attr.name).to eq("id2")
    expect(attr.content).to eq("2")

    expect(attrs["id"].content).to eq("1")
    expect(attrs["id2"].content).to eq("2")

    expect(attrs["id3"]?).to be_nil
    expect_raises(MissingKey) { attrs["id3"] }

    expect(person["id"]).to eq("1")
    expect(person["id2"]).to eq("2")
    expect(person["id3"]?).to be_nil
    expect_raises(MissingKey) { person["id3"] }

    name = person.children.find { |node| node.name == "name" }.not_nil!
    expect(name.content).to eq("John")

    expect(name.parent).to eq(person)
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
    expect(doc.document).to eq(doc)
    expect(doc.name).to eq("document")

    people = doc.children.find { |node| node.name == "people" }.not_nil!
    person = people.children.find { |node| node.name == "person" }.not_nil!
    expect(person["id"]).to eq("1")
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
    expect(doc.to_s.strip).to eq(<<-XML
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
    expect(people.name).to eq("people")

    person = people.first_element_child.not_nil!
    expect(person.name).to eq("person")
    expect(person["id"]).to eq("1")

    text = person.next.not_nil!
    expect(text.content).to eq("\n        ")

    expect(text.previous).to eq(person)
    expect(text.previous_sibling).to eq(person)

    expect(person.next_sibling).to eq(text)

    person2 = text.next.not_nil!
    expect(person2.name).to eq("person")
    expect(person2["id"]).to eq("2")

    expect(person.next_element).to eq(person2)
    expect(person2.previous_element).to eq(person)
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

    expect(namespaces.length).to eq(2)
    expect(namespaces[0].href).to eq("http://www.w3.org/2005/Atom")
    expect(namespaces[0].prefix).to be_nil
    expect(namespaces[1].href).to eq("http://a9.com/-/spec/opensearchrss/1.0/")
    expect(namespaces[1].prefix).to eq("openSearch")
  end

  it "gets root namespaces as hash" do
    doc = XML.parse(%(\
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/">
      </feed>
      ))
    namespaces = doc.root.not_nil!.namespaces
    expect(namespaces).to eq({
      "xmlns" => "http://www.w3.org/2005/Atom",
      "xmlns:openSearch": "http://a9.com/-/spec/opensearchrss/1.0/",
    })
  end
end
