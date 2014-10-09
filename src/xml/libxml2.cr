@[Link("xml2")]
lib LibXML
  type InputBuffer = Void*
  type XmlTextReader = Void*

  XML_READER_TYPE_NONE                   = 0
  XML_READER_TYPE_ELEMENT                = 1
  XML_READER_TYPE_ATTRIBUTE              = 2
  XML_READER_TYPE_TEXT                   = 3
  XML_READER_TYPE_CDATA                  = 4
  XML_READER_TYPE_ENTITY_REFERENCE       = 5
  XML_READER_TYPE_ENTITY                 = 6
  XML_READER_TYPE_PROCESSING_INSTRUCTION = 7
  XML_READER_TYPE_COMMENT                = 8
  XML_READER_TYPE_DOCUMENT               = 9
  XML_READER_TYPE_DOCUMENT_TYPE          = 10
  XML_READER_TYPE_DOCUMENT_FRAGMENT      = 11
  XML_READER_TYPE_NOTATION               = 12
  XML_READER_TYPE_WHITESPACE             = 13
  XML_READER_TYPE_SIGNIFICANT_WHITESPACE = 14
  XML_READER_TYPE_END_ELEMENT            = 15
  XML_READER_TYPE_END_ENTITY             = 16
  XML_READER_TYPE_XML_DECLARATION        = 17

  fun xmlParserInputBufferCreateStatic(mem : UInt8*, size : Int32, encoding : Int32) : InputBuffer
  fun xmlNewTextReader(input : InputBuffer, uri : UInt8*) : XmlTextReader

  fun xmlTextReaderRead(reader : XmlTextReader) : Int32
  fun xmlTextReaderNodeType(reader : XmlTextReader) : Int32
  fun xmlTextReaderConstName(reader : XmlTextReader) : UInt8*
  fun xmlTextReaderIsEmptyElement(reader : XmlTextReader) : Int32
  fun xmlTextReaderConstValue(reader : XmlTextReader) : UInt8*
end
