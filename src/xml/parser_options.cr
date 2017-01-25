@[Flags]
enum XML::ParserOptions
  # Recover on errors
  RECOVER = 1

  # Substitute entities
  NOENT = 2

  # Load the external subset
  DTDLOAD = 4

  # Default DTD attributes
  DTDATTR = 8

  # Validate with the DTD
  DTDVALID = 16

  # Suppress error reports
  NOERROR = 32

  # Suppress warning reports
  NOWARNING = 64

  # Pedantic error reporting
  PEDANTIC = 128

  # Remove blank nodes
  NOBLANKS = 256

  # Use the SAX1 interface internally
  SAX1 = 512

  # Implement XInclude substitution
  XINCLUDE = 1024

  # Forbid network access
  NONET = 2048

  # Do not reuse the context dictionary
  NODICT = 4096

  # Remove redundant namespaces declarations
  NSCLEAN = 8192

  # Merge CDATA as text nodes
  NOCDATA = 16384

  # Do not generate XINCLUDE START/END nodes
  NOXINCNODE = 32768

  # Compact small text nodes; no modification of the tree allowed afterwards (will possibly crash if you try to modify the tree)
  COMPACT = 65536

  # Parse using XML-1.0 before update 5
  OLD10 = 131072

  # Do not fixup XINCLUDE xml:base uris
  NOBASEFIX = 262144

  # Relax any hardcoded limit from the parser
  HUGE = 524288

  # Parse using SAX2 interface before 2.7.0
  OLDSAX = 1048576

  # Ignore internal document encoding hint
  IGNORE_ENC = 2097152

  # Store big lines numbers in text PSVI field
  BIG_LINES = 4194304

  # Returns default options for parsing XML documents.
  #
  # Default flags are: `RECOVER` | `NOERROR` | `NOWARNING` | `NONET`
  def self.default : self
    RECOVER | NOERROR | NOWARNING | NONET
  end
end
