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
  @__xml_global_state : Void* = Pointer(Void).null

  # FIXME: "fix" this magic number; this is sizeof(xmlGlobalState) for Mac OS X
  # 64 bits
  XML_GLOBAL_STATE_SIZE = 968

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
    @__xml_global_state = LibXML.xmlGetGlobalState
  end

  protected def xml_push_gc_roots
    return unless @__xml_global_state
    LibGC.push_all @__xml_global_state, @__xml_global_state + XML_GLOBAL_STATE_SIZE
  end

  # TODO: provide a nicer interface to registering other roots pushers in GC
  # See also fiber.cr
  @@__xml_prev_push_other_roots : ->
  @@__xml_prev_push_other_roots = LibGC.get_push_other_roots

  LibGC.set_push_other_roots ->do
    @@threads_mutex.synchronize do
      @@threads.each do |thread|
        thread.xml_push_gc_roots
      end
    end
    @@__xml_prev_push_other_roots.call
  end
end
