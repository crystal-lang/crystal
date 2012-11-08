class Logger
  class << self
    def indent
      @level ||= 0
      @level += 1
    end

    def unindent
      @level -= 1
    end

    def log(message)
      return unless Crystal::LOG
      print '  ' * @level if @level
      puts message
    end
  end
end