@[Flags]
enum XML::HTMLParserOptions
  # Relaxed parsing
  RECOVER = 1

  # Do not default a doctype if not found
  NODEFDTD = 4

  # Suppress error reports
  NOERROR = 32

  # Suppress warning reports
  NOWARNING = 64

  # Pedantic error reporting
  PEDANTIC = 128

  # Remove blank nodes
  NOBLANKS = 256

  # Forbid network access
  NONET = 2048

  # Do not add implied html/body... elements
  NOIMPLIED = 8192

  # Compact small text nodes
  COMPACT = 65536

  # Ignore internal document encoding hint
  IGNORE_ENC = 2097152

  # Returns default options for parsing HTML documents.
  #
  # Default flags are: `RECOVER` | `NOERROR` | `NOWARNING`
  def self.default : self
    RECOVER | NOERROR | NOWARNING
  end
end
