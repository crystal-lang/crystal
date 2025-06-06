class Thread
  struct Local(T)
    # def initialize
    #   {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
    # end

    # def initialize(&destructor : Proc(T, Nil))
    #   {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
    # end

    def get(& : -> T) : T
      get? || set(yield)
    end

    # def get? : T?
    # def set(value : T) : T
  end
end

{% if flag?(:wasi) %}
  require "./wasi/thread_local"
{% elsif flag?(:unix) %}
  require "./unix/thread_local"
{% elsif flag?(:win32) %}
  require "./win32/thread_local"
{% else %}
  {% raise "Thread not supported" %}
{% end %}
