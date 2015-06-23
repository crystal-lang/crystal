class Regex
  def save(output : Marshaler)
    @options.save(output)
    @source.save(output)
  end

  def self.load(input : Unmarshaler)
    options = Regex::Options.load(input)
    source = String.load(input)
    new(source, options)
  end
end
