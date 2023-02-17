require "spec"
require "xml"

private def xml
  <<-XML
  <?xml version="1.0" encoding="UTF-8"?>
  <people>
    <person id="1">
      <name>John</name>
    </person>
    <person id="2">
      <name>Peter</name>
    </person>
  </people>
  XML
end

module XML
  describe Reader do
    describe ".new" do
      context "with default parser options" do
        it "can be initialized from a string" do
          reader = Reader.new(xml)
          reader.should be_a(XML::Reader)
          reader.read.should be_true
          reader.name.should eq("people")
          reader.read.should be_true
          reader.name.should eq("#text")
        end

        it "can be initialized from an io" do
          io = IO::Memory.new(xml)
          reader = Reader.new(io)
          reader.should be_a(XML::Reader)
          reader.read.should be_true
          reader.name.should eq("people")
          reader.read.should be_true
          reader.name.should eq("#text")
        end
      end

      context "with custom parser options" do
        it "can be initialized from a string" do
          reader = Reader.new(xml, XML::ParserOptions::NOBLANKS)
          reader.should be_a(XML::Reader)
          reader.read.should be_true
          reader.name.should eq("people")
          reader.read.should be_true
          reader.name.should eq("person")
        end

        it "can be initialized from an io" do
          io = IO::Memory.new(xml)
          reader = Reader.new(io, XML::ParserOptions::NOBLANKS)
          reader.should be_a(XML::Reader)
          reader.read.should be_true
          reader.name.should eq("people")
          reader.read.should be_true
          reader.name.should eq("person")
        end
      end
    end

    describe "#read" do
      it "reads all nodes" do
        reader = Reader.new(xml)
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("people")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("1")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::TEXT)
        reader.name.should eq("#text")
        reader.value.should eq("John")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("person")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("2")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::TEXT)
        reader.name.should eq("#text")
        reader.value.should eq("Peter")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("person")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("people")
        reader.read.should be_false
      end

      it "reads all non-blank nodes with NOBLANKS option" do
        reader = Reader.new(xml, XML::ParserOptions::NOBLANKS)
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("people")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("1")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::TEXT)
        reader.name.should eq("#text")
        reader.value.should eq("John")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("person")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("2")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::TEXT)
        reader.name.should eq("#text")
        reader.value.should eq("Peter")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("name")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("person")
        reader.read.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("people")
        reader.read.should be_false
      end
    end

    describe "#next" do
      it "reads next node in doc order, skipping subtrees" do
        reader = Reader.new(xml)
        while reader.read
          break if reader.depth == 2
        end
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("name")
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("1")
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("2")
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.next.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("people")
        reader.next.should be_false
      end
    end

    describe "#next_sibling" do
      it "reads next sibling node in doc order, skipping subtrees" do
        reader = Reader.new(xml)
        while reader.read
          break if reader.depth == 1
        end
        reader.next_sibling.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("1")
        reader.next_sibling.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.next_sibling.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("person")
        reader["id"].should eq("2")
        reader.next_sibling.should be_true
        reader.node_type.should eq(XML::Reader::Type::SIGNIFICANT_WHITESPACE)
        reader.name.should eq("#text")
        reader.next_sibling.should be_false
      end
    end

    describe "#node_type" do
      it "returns the node type" do
        reader = Reader.new("<root/>")
        reader.node_type.should eq(XML::Reader::Type::NONE)
        reader.read
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
      end
    end

    describe "#name" do
      it "reads node name" do
        reader = Reader.new("<root/>")
        reader.name.should eq("")
        reader.read
        reader.name.should eq("root")
      end
    end

    describe "#empty_element?" do
      it "checks if the node is empty" do
        reader = Reader.new("<root/>")
        reader.empty_element?.should be_false
        reader.read
        reader.empty_element?.should be_true
        reader = Reader.new("<root></root>")
        reader.read
        reader.empty_element?.should be_false
      end
    end

    describe "#has_attributes?" do
      it "checks if the node has attributes" do
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.has_attributes?.should be_false
        reader.read # <root id="1">
        reader.has_attributes?.should be_true
        reader.read # <child/>
        reader.has_attributes?.should be_false
        reader.read # </root>
        reader.has_attributes?.should be_true
      end
    end

    describe "#attributes_count" do
      it "returns the node's number of attributes" do
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.attributes_count.should eq(0)
        reader.read # <root id="1">
        reader.attributes_count.should eq(1)
        reader.read # <child/>
        reader.attributes_count.should eq(0)
        reader.read # </root>
        # This is weird, since has_attributes? will be true.
        reader.attributes_count.should eq(0)
      end
    end

    describe "#move_to_first_attribute" do
      it "moves to the first attribute of the node" do
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.move_to_first_attribute.should be_false
        reader.read # <root id="1">
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.move_to_first_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.value.should eq("1")
        reader.read # <child/>
        reader.move_to_first_attribute.should be_false
        reader.read # </root>
        reader.move_to_first_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.value.should eq("1")
        reader.read.should be_false
      end
    end

    describe "#move_to_next_attribute" do
      it "moves to the next attribute of the node" do
        reader = Reader.new(%{<root id="1" id2="2"><child/></root>})
        reader.move_to_next_attribute.should be_false
        reader.read # <root id="1" id2="2">
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.move_to_next_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.value.should eq("1")
        reader.move_to_next_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id2")
        reader.value.should eq("2")
        reader.move_to_next_attribute.should be_false
        reader.read # <child/>
        reader.move_to_next_attribute.should be_false
        reader.read # </root>
        reader.move_to_next_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.value.should eq("1")
        reader.read.should be_false
      end
    end

    describe "#move_to_attribute" do
      it "moves to attribute with the specified name" do
        reader = Reader.new(%{<root id="1" id2="2"><child/></root>})
        reader.move_to_attribute("id2").should be_false
        reader.read # <root id="1" id2="2">
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.move_to_attribute("id2").should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id2")
        reader.value.should eq("2")
        reader.move_to_attribute("id").should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.value.should eq("1")
        reader.move_to_attribute("bogus").should be_false
        reader.read # <child/>
        reader.move_to_attribute("id2").should be_false
        reader.read # </root>
        reader.move_to_attribute("id2").should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id2")
        reader.value.should eq("2")
        reader.read.should be_false
      end
    end

    describe "#[]" do
      it "reads node attributes" do
        reader = Reader.new("<root/>")
        expect_raises(KeyError) { reader["id"] }
        reader.read
        expect_raises(KeyError) { reader["id"] }
        reader = Reader.new(%{<root id="1"/>})
        reader.read
        reader["id"].should eq("1")
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.read # <root id="1">
        reader["id"].should eq("1")
        reader.read # <child/>
        expect_raises(KeyError) { reader["id"] }
        reader.read # </root>
        reader["id"].should eq("1")
      end
    end

    describe "#[]?" do
      it "reads node attributes" do
        reader = Reader.new("<root/>")
        reader["id"]?.should be_nil
        reader.read
        reader["id"]?.should be_nil
        reader = Reader.new(%{<root id="1"/>})
        reader.read
        reader["id"]?.should eq("1")
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.read # <root id="1">
        reader["id"]?.should eq("1")
        reader.read # <child/>
        reader["id"]?.should be_nil
        reader.read # </root>
        reader["id"]?.should eq("1")
      end
    end

    describe "#move_to_element" do
      it "moves to the element node that contains the current attribute node" do
        reader = Reader.new(%{<root id="1"></root>})
        reader.move_to_element.should be_false
        reader.read # <root id="1">
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("root")
        reader.move_to_element.should be_false
        reader.move_to_first_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.move_to_element.should be_true
        reader.node_type.should eq(XML::Reader::Type::ELEMENT)
        reader.name.should eq("root")
        reader.read # </root>
        reader.move_to_element.should be_false
        reader.move_to_first_attribute.should be_true
        reader.node_type.should eq(XML::Reader::Type::ATTRIBUTE)
        reader.name.should eq("id")
        reader.move_to_element.should be_true
        reader.node_type.should eq(XML::Reader::Type::END_ELEMENT)
        reader.name.should eq("root")
        reader.read.should be_false
      end
    end

    describe "#depth" do
      it "returns the depth of the node" do
        reader = Reader.new("<root><child/></root>")
        reader.depth.should eq(0)
        reader.read # <root>
        reader.depth.should eq(0)
        reader.read # <child/>
        reader.depth.should eq(1)
        reader.read # </root>
        reader.depth.should eq(0)
      end
    end

    describe "#read_inner_xml" do
      it "reads the contents of the node including child nodes and markup" do
        reader = Reader.new("<root>\n<child/>\n</root>\n")
        reader.read_inner_xml.should eq("")
        reader.read # <root>
        reader.read_inner_xml.should eq("\n<child/>\n")
        reader.read # \n
        reader.read_inner_xml.should eq("")
        reader.read # <child/>
        reader.read_inner_xml.should eq("")
        reader.read # \n
        reader.read_inner_xml.should eq("")
        reader.read # </root>
        reader.read_inner_xml.should eq("")
        reader.read.should be_false
      end
    end

    describe "#read_outer_xml" do
      it "reads the xml of the node including child nodes and markup" do
        reader = Reader.new("<root>\n<child/>\n</root>\n")
        reader.read_outer_xml.should eq("")
        reader.read # <root>
        reader.read_outer_xml.should eq("<root>\n<child/>\n</root>")
        reader.read # \n
        reader.read_outer_xml.should eq("\n")
        reader.read # <child/>
        reader.read_outer_xml.should eq("<child/>")
        reader.read # \n
        reader.read_outer_xml.should eq("\n")
        reader.read # </root>
        # Note that the closing element is transformed into a self-closing one.
        reader.read_outer_xml.should eq("<root/>")
        reader.read.should be_false
      end
    end

    describe "#expand" do
      it "raises an exception if the node could not be expanded" do
        reader = Reader.new(%{<root id="1<child/></root>}) # Invalid XML
        reader.read
        expect_raises XML::Error, "Couldn't find end of Start Tag root" do
          reader.expand
        end
      end

      it "parses the content of the node and subtree" do
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.read # <root id="1">
        node = reader.expand
        node.should be_a(XML::Node)
        node.attributes["id"].content.should eq("1")
        node.xpath_node("child").should be_a(XML::Node)
      end

      it "is only available until the next read" do
        reader = Reader.new(%{<root><child><subchild/></child></root>})
        reader.read # <root>
        reader.read # <child>
        node = reader.expand
        node.should be_a(XML::Node)
        node.xpath_node("subchild").should be_a(XML::Node)
        reader.read # <subchild/>
        reader.read # </child>
        node.xpath_node("subchild").should be_nil
      end
    end

    describe "#expand?" do
      it "parses the content of the node and subtree" do
        reader = Reader.new(%{<root id="1"><child/></root>})
        reader.expand?.should be_nil
        reader.read # <root id="1">
        node = reader.expand?
        node.should be_a(XML::Node)
        node.not_nil!.attributes["id"].content.should eq("1")
        node.not_nil!.xpath_node("child").should be_a(XML::Node)
      end

      it "is only available until the next read" do
        reader = Reader.new(%{<root><child><subchild/></child></root>})
        reader.read # <root>
        reader.read # <child>
        node = reader.expand?
        node.should be_a(XML::Node)
        node.not_nil!.xpath_node("subchild").should be_a(XML::Node)
        reader.read # <subchild/>
        reader.read # </child>
        node.not_nil!.xpath_node("subchild").should be_nil
      end
    end

    describe "#value" do
      it "reads node text value" do
        reader = Reader.new(%{<root id="1">hello<!-- world --></root>})
        reader.value.should eq("")
        reader.read # <root>
        reader.value.should eq("")
        reader.read # hello
        reader.value.should eq("hello")
        reader.read # <!-- world -->
        reader.value.should eq(" world ")
        reader.read # </root>
        reader.move_to_first_attribute.should be_true
        reader.value.should eq("1")
      end
    end

    describe "#to_unsafe" do
      it "returns a pointer to the underlying LibXML::XMLTextReader" do
        reader = Reader.new("<root/>")
        reader.to_unsafe.should be_a(LibXML::XMLTextReader)
      end
    end
  end

  describe "#errors" do
    it "makes errors accessible" do
      reader = XML::Reader.new(%(<people></foo>))
      reader.read
      reader.expand?

      reader.errors.map(&.to_s).should eq ["Opening and ending tag mismatch: people line 1 and foo"]
    end

    it "adds errors to `XML::Error.errors` (deprecated)" do
      XML::Error.errors # clear class error list

      reader = XML::Reader.new(%(<people></foo>))
      reader.read
      reader.expand?

      XML::Error.errors.try(&.map(&.to_s)).should eq ["Opening and ending tag mismatch: people line 1 and foo"]
    end
  end
end
