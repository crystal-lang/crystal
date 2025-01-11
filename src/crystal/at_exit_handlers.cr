# :nodoc:
module Crystal::AtExitHandlers
  private class_getter(handlers) { [] of Int32, ::Exception? -> }
  private class_getter(internal_handlers) { [] of Int32, ::Exception? -> }

  def self.add(handler)
    handlers << handler
  end

  def self.__crystal_add(handler)
    internal_handlers << handler
  end

  def self.run(status, exception = nil)
    if handlers = @@handlers
      # Run the registered handlers in reverse order
      while handler = handlers.pop?
        begin
          handler.call status, exception
        rescue handler_ex
          Crystal::System.print_error "Error running at_exit handler: %s\n", handler_ex.message || ""
          status = 1 if status.zero?
        end
      end
    end

    if internal_handlers = @@internal_handlers
      # Run the registered internal handlers in reverse order
      while handler = internal_handlers.pop?
        begin
          handler.call status, exception
        rescue handler_ex
          Crystal::System.print_error "Error running internal at_exit handler: %s\n", handler_ex.message || ""
          status = 1 if status.zero?
        end
      end
    end

    status
  end
end
