require "./libxml2"

class XML::Error < Exception
  getter line_number : Int32

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
    # TODO: use va_start and va_end to
    message = String.new(fmt).chomp
    error = XML::Error.new(message, 0)

    {% if flag?(:arm) || flag?(:aarch64) %}
      # libxml2 is likely missing ARM unwind tables (.ARM.extab and .ARM.exidx
      # sections) which prevent raising from a libxml2 context.
      @@errors << error
    {% else %}
      raise error
    {% end %}
  }

  # :nodoc:
  def self.set_errors(node)
    if errors = self.errors
      node.errors = errors
    end
  end

  def self.errors
    if @@errors.empty?
      nil
    else
      errors = @@errors.dup
      @@errors.clear
      errors
    end
  end
end
