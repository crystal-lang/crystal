require "./libxml2"

class XML::Error < Exception
  getter line_number : Int32

  def self.new(error : LibXML::Error*)
    new String.new(error.value.message).chomp, error.value.line
  end

  def initialize(message, @line_number)
    super(message)
  end

  @@max_error_capacity = 5

  @[Deprecated("This class property is deprecated. XML errors are accessible directly in the respective context via `XML::Reader#errors` and `XML::Node#errors`.")]
  def self.max_error_capacity=(@@max_error_capacity)
  end

  @[Deprecated("This class property is deprecated. XML errors are accessible directly in the respective context via `XML::Reader#errors` and `XML::Node#errors`.")]
  def self.max_error_capacity
    @@max_error_capacity
  end

  @@errors = Deque(self).new(max_error_capacity)

  # :nodoc:
  protected def self.add_errors(errors)
    new_errors_size = errors.size.clamp(..max_error_capacity)
    remaining_size = max_error_capacity - new_errors_size
    (@@errors.size - remaining_size).times { @@errors.shift }

    errors.to_unsafe.to_slice(errors.size)[-new_errors_size, new_errors_size].each do |error|
      @@errors.push error
    end
  end

  @[Deprecated("This class accessor is deprecated. XML errors are accessible directly in the respective context via `XML::Reader#errors` and `XML::Node#errors`.")]
  def self.errors : Array(XML::Error)?
    if @@errors.empty?
      nil
    else
      errors = @@errors.to_a
      @@errors.clear
      errors
    end
  end

  def self.collect(errors, &)
    LibXML.xmlSetStructuredErrorFunc Box.box(errors), ->(ctx, error) {
      Box(Array(XML::Error)).unbox(ctx) << XML::Error.new(error)
    }
    begin
      yield
    ensure
      LibXML.xmlSetStructuredErrorFunc nil, nil
    end
  end

  def self.collect_generic(errors, &)
    LibXML.xmlSetGenericErrorFunc Box.box(errors), ->(ctx, fmt) {
      # TODO: use va_start and va_end to
      message = String.new(fmt).chomp
      error = XML::Error.new(message, 0)

      {% if flag?(:arm) || flag?(:aarch64) %}
        # libxml2 is likely missing ARM unwind tables (.ARM.extab and .ARM.exidx
        # sections) which prevent raising from a libxml2 context.
        Box(Array(XML::Error)).unbox(ctx) << error
      {% else %}
        raise error
      {% end %}
    }

    begin
      collect(errors) do
        yield
      end
    ensure
      LibXML.xmlSetGenericErrorFunc nil, nil
    end
  end
end
