require "./*"

module XML
  def self.parse(string_or_io)
    Document.parse(string_or_io)
  end
end
