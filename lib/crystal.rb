module Crystal
  class Exception < StandardError
    attr_accessor :line_number

    def initialize(message, line_number)
      super(message)
      @line_number = line_number
    end
  end
end

Dir["#{File.expand_path('../',  __FILE__)}/**/*.rb"].each do |filename|
  require filename
end
