require "./libxml2"

class XML::Error < Exception
  getter line_number : Int32

  def self.new(error : LibXML::Error*)
    new String.new(error.value.message).chomp, error.value.line
  end

  def initialize(message, @line_number)
    super(message)
  end

  def self.init_thread_error_handling
    Thread.current.xml_init_error_handling
  end

  # :nodoc:
  def self.set_errors(node)
    if errors = self.errors
      node.errors = errors
    end
  end

  def self.errors
    xml_errors = Thread.current.xml_errors
    if xml_errors.empty?
      nil
    else
      errors = xml_errors.dup
      xml_errors.clear
      errors
    end
  end
end

class Thread
  @__xml_errors = [] of XML::Error
  @__xml_errors_initialized = false

  def xml_errors
    @__xml_errors
  end

  def xml_init_error_handling
    return if @__xml_errors_initialized

    LibXML.xmlSetStructuredErrorFunc self.as(Void*), ->(ctx, error) {
      thread = ctx.as(Thread)
      thread.xml_errors << XML::Error.new(error)
    }

    LibXML.xmlSetGenericErrorFunc self.as(Void*), ->(ctx, fmt) {
      thread = ctx.as(Thread)
      # TODO: use va_start and va_end to
      message = String.new(fmt).chomp
      error = XML::Error.new(message, 0)

      {% if flag?(:arm) || flag?(:aarch64) %}
        # libxml2 is likely missing ARM unwind tables (.ARM.extab and .ARM.exidx
        # sections) which prevent raising from a libxml2 context.
        thread.xml_errors << error
      {% else %}
        raise error
      {% end %}
    }
    @__xml_errors_initialized = true
  end
end
