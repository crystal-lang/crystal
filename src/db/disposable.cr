module DB
  # Generic module to encapsulate disposable db resources.
  module Disposable
    macro included
      @closed = false
    end

    # Closes this object.
    def close
      return if @closed
      @closed = true
      do_close
    end

    # Returns `true` if this object is closed. See `#close`.
    def closed?
      @closed
    end

    # :nodoc:
    def finalize
      close
    end

    # Implementors overrides this method to perform resource cleanup
    protected abstract def do_close
  end
end
