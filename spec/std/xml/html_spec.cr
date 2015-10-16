require "spec"
require "xml"

describe XML do
  it "parses HTML" do
    doc = XML.parse_html(%(\
      <!doctype html>
      <html>
      <head>
          <title>Samantha</title>
      </head>
      <body>
          <h1 class="large">Boat</h1>
      </body>
      </html>
    ))

    html = doc.children[1]
    html.name.should eq("html")

    head = html.children.find { |node| node.name == "head" }.not_nil!
    head.name.should eq("head")

    title = head.children.find { |node| node.name == "title" }.not_nil!
    title.text.should eq("Samantha")

    body = html.children.find { |node| node.name == "body" }.not_nil!

    h1 = body.children.find { |node| node.name == "h1" }.not_nil!

    attrs = h1.attributes
    attrs.empty?.should be_false
    attrs.size.should eq(1)

    attr = attrs[0]
    attr.name.should eq("class")
    attr.content.should eq("large")
    attr.text.should eq("large")
    attr.inner_text.should eq("large")
  end

  it "parses HTML from IO" do
    io = MemoryIO.new(%(\
      <!doctype html>
      <html>
      <head>
          <title>Samantha</title>
      </head>
      <body>
          <h1 class="large">Boat</h1>
      </body>
      </html>
    ))

    doc = XML.parse_html(io)
    html = doc.children[1]
    html.name.should eq("html")
  end

  it "parses html5 (#1404)" do
    html5 = "<html><body><nav>Test</nav></body></html>"
    xml = XML.parse_html(html5)
    xml.errors.should_not be_nil
    xml.xpath_node("//html/body/nav").should_not be_nil
  end
end
