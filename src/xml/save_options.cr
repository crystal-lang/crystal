@[Flags]
enum XML::SaveOptions
  # Format save output
  FORMAT = 1

  # Drop the xml declaration
  NO_DECL = 2

  # No empty tags
  NO_EMPTY = 4

  # Disable XHTML1 specific rules
  NO_XHTML = 8

  # Force XHTML1 specific rules
  XHTML = 16

  # Force XML serialization on HTML doc
  AS_XML = 32

  # Force HTML serialization on XML doc
  AS_HTML = 64

  # Format with non-significant whitespace
  WSNONSIG = 128

  def self.xml_default : self
    FORMAT | AS_XML
  end
end
