require "./libxml2"

class XML::Error < Exception
  getter line_number

  def self.new(error : LibXML::Error*)
    new String.new(error.value.message).chomp, error.value.line
  end

  def initialize(message, @line_number)
    super(message)
  end
end

LibXML.xmlSetStructuredErrorFunc nil, ->(ctx, error) {
  raise XML::Error.new(error)
}

LibXML.xmlSetGenericErrorFunc nil, ->(ctx, fmt) {
  # TODO: use va_start and va_end
  raise XML::Error.new(String.new(fmt).chomp, 0)
}
