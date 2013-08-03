require "libxml2"

module Xml
  class Reader
    def initialize(str : String)
      input = LibXML.xmlParserInputBufferCreateStatic(str, str.length, 22)
      @reader = LibXML.xmlNewTextReader(input, "")
    end

    def read
      LibXML.xmlTextReaderRead(@reader) == 1
    end

    def node_type
      case LibXML.xmlTextReaderNodeType(@reader)
      when LibXML::XML_READER_TYPE_ELEMENT                then :element
      when LibXML::XML_READER_TYPE_ATTRIBUTE              then :attribute
      when LibXML::XML_READER_TYPE_TEXT                   then :text
      when LibXML::XML_READER_TYPE_CDATA                  then :cdata
      when LibXML::XML_READER_TYPE_ENTITY_REFERENCE       then :entity_reference
      when LibXML::XML_READER_TYPE_ENTITY                 then :entity
      when LibXML::XML_READER_TYPE_PROCESSING_INSTRUCTION then :processing_instruction
      when LibXML::XML_READER_TYPE_COMMENT                then :comment
      when LibXML::XML_READER_TYPE_DOCUMENT               then :document
      when LibXML::XML_READER_TYPE_DOCUMENT_TYPE          then :document_type
      when LibXML::XML_READER_TYPE_DOCUMENT_FRAGMENT      then :document_fragment
      when LibXML::XML_READER_TYPE_NOTATION               then :notation
      when LibXML::XML_READER_TYPE_WHITESPACE             then :whitespace
      when LibXML::XML_READER_TYPE_SIGNIFICANT_WHITESPACE then :significant_whitespace
      when LibXML::XML_READER_TYPE_END_ELEMENT            then :end_element
      when LibXML::XML_READER_TYPE_END_ENTITY             then :end_entity
      when LibXML::XML_READER_TYPE_XML_DECLARATION        then :xml_declaration
      else :none
      end
    end

    def name
      String.from_cstr(LibXML.xmlTextReaderConstName(@reader))
    end

    def is_empty_element
      LibXML.xmlTextReaderIsEmptyElement(@reader) == 1
    end

    def value
      String.from_cstr(LibXML.xmlTextReaderConstValue(@reader))
    end
  end
end
