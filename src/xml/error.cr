require "./libxml2"

class XML::Error < Exception
  getter line_number

  def self.new(error : LibXML::Error*)
    new String.new(error.value.message).chomp, error.value.line
  end

  def initialize(message, @line_number)
    super(message)
  end

  # TODO: this logic isn't thread/fiber safe, but error checking is less needed than
  # the ability to parse HTML5 and malformed documents. In any case, fix this.
  @@errors = [] of self

  LibXML.xmlSetStructuredErrorFunc nil, ->(ctx, error) {
    @@errors << XML::Error.new(error)
  }

  LibXML.xmlSetGenericErrorFunc nil, ->(ctx, fmt) {
    # TODO: use va_start and va_end
    raise XML::Error.new(String.new(fmt).chomp, 0)
  }

  # :nodoc:
  def self.set_errors(node)
    unless @@errors.empty?
      node.errors = @@errors.dup
      @@errors.clear
    end
  end
end
