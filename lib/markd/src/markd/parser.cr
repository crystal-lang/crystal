module Markd
  module Parser
    def self.parse(source : String, options = Options.new)
      Block.parse(source, options)
    end
  end
end

require "./parsers/*"
