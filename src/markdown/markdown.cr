class Markdown
  def self.parse(text, renderer)
    parser = Parser.new(text, renderer)
    parser.parse
  end

  def self.to_html(text)
    String.build do |io|
      parse text, Markdown::HTMLRenderer.new(io)
    end
  end
end

require "./*"
