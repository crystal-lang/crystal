require "./libxml2"

class XML::Error < Exception
  getter line_number : Int32

  def self.new(error : LibXML::Error*)
    new String.new(error.value.message).chomp, error.value.line
  end

  def initialize(message, @line_number)
    super(message)
  end

  @[Deprecated("This class accessor is deprecated. XML errors are accessible directly in the respective context via `XML::Reader#errors` and `XML::Node#errors`.")]
  def self.errors : Array(XML::Error)?
    {% raise "`XML::Error.errors` was removed because it leaks memory when it's not used. XML errors are accessible directly in the respective context via `XML::Reader#errors` and `XML::Node#errors`.\nSee https://github.com/crystal-lang/crystal/issues/14934 for details. " %}
  end

  protected def self.structured_callback(data : Void*, error : LibXML::Error*) : Nil
    Box(Array(Error)).unbox(data) << Error.new(error)
  end

  protected def self.generic_callback(data : Void*, fmt : UInt8*) : Nil
    message = String.new(fmt).chomp
    Box(Array(Error)).unbox(data) << XML::Error.new(message, 0)
  end

  # Saves the global error handlers (and user data) for the current thread,
  # replaces them with a custom handler to record reported XML errors in
  # *errors*, and eventually restores the saved error handlers (and user data)
  # before returning.
  #
  # Saves both structured + generic handlers because libxml < 2.13 use *both* in
  # practice.
  #
  # NOTE: This is for internal compatibility with libxml < 2.13. Do not use.
  protected def self.unsafe_collect(errors : Array(Error), &)
    data = Box.box(errors)
    with_handlers(data, ->structured_callback(Void*, LibXML::Error*), data, ->generic_callback(Void*, UInt8*)) { yield }
  end

  # Saves the current global error handlers (and user data) and restore the
  # default handlers for the duration of the block. Eventually restores the
  # saved error handlers (and user data) before returning.
  #
  # Use this when a callback can potentially do a fiber context switch, for
  # example IO operations.
  #
  # Saves both structured + generic handlers because libxml < 2.13 use *both* in
  # practice.
  #
  # NOTE: This is for internal compatibility with libxml < 2.13. Do not use.
  protected def self.default_handlers(&)
    with_handlers(nil, nil, nil, nil) { yield }
  end

  private def self.with_handlers(scontext, shandler, context, handler, &)
    orig_scontext = LibXML.__xmlStructuredErrorContext.value
    orig_shandler = LibXML.__xmlStructuredError.value

    orig_context = LibXML.__xmlGenericErrorContext.value
    orig_handler = LibXML.__xmlGenericError.value

    LibXML.xmlSetStructuredErrorFunc(scontext, shandler)
    LibXML.xmlSetGenericErrorFunc(context, handler)

    begin
      yield
    ensure
      # can't call xmlSetStructuredErrorFunc or xmlSetGenericErrorFunc: the
      # compiler complains that it's passing a closure to C (it's not)
      LibXML.__xmlStructuredErrorContext.value = orig_scontext
      LibXML.__xmlStructuredError.value = orig_shandler

      LibXML.__xmlGenericErrorContext.value = orig_context
      LibXML.__xmlGenericError.value = orig_handler
    end
  end

  @[Deprecated("Legacy libxml2 API that mutate global state. Do not use.")]
  def self.collect(errors, &)
    unsafe_collect(errors) { yield }
  end

  @[Deprecated("Legacy libxml2 API that mutate global state. Do not use.")]
  def self.collect_generic(errors, &)
    LibXML.xmlSetGenericErrorFunc Box.box(errors), ->(data, fmt) {
      # TODO: use va_start and va_end to
      message = String.new(fmt).chomp
      error = XML::Error.new(message, 0)

      {% if flag?(:arm) || flag?(:aarch64) %}
        # libxml2 is likely missing ARM unwind tables (.ARM.extab and .ARM.exidx
        # sections) which prevent raising from a libxml2 context.
        Box(Array(XML::Error)).unbox(data) << error
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
