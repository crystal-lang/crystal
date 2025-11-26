# :nodoc:
module Crystal::AtExitHandlers
  @@mutex = ::Thread::Mutex.new

  def self.add(handler)
    @@mutex.synchronize do
      handlers = @@handlers ||= [] of Int32, ::Exception? ->
      handlers << handler
    end
  end

  def self.run(status, exception = nil)
    return status unless @@handlers

    # Run the registered handlers in reverse order
    while handler = @@mutex.synchronize { @@handlers.try(&.pop?) }
      begin
        handler.call status, exception
      rescue handler_ex
        Crystal::System.print_error "Error running at_exit handler: %s\n", handler_ex.message || ""
        status = 1 if status.zero?
      end
    end

    status
  end
end
