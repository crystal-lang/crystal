class XML::Reader
  enum Type
    NONE                   =  0
    ELEMENT                =  1
    ATTRIBUTE              =  2
    TEXT                   =  3
    CDATA                  =  4
    ENTITY_REFERENCE       =  5
    ENTITY                 =  6
    PROCESSING_INSTRUCTION =  7
    COMMENT                =  8
    DOCUMENT               =  9
    DOCUMENT_TYPE          = 10
    DOCUMENT_FRAGMENT      = 11
    NOTATION               = 12
    WHITESPACE             = 13
    SIGNIFICANT_WHITESPACE = 14
    END_ELEMENT            = 15
    END_ENTITY             = 16
    XML_DECLARATION        = 17
  end
end
