module Crystal::Doc::Markdown
  # :nodoc:
  module Utils
    DECODE_ENTITIES_REGEX = Regex.new("\\\\" + Rule::ESCAPABLE_STRING, Regex::Options::IGNORE_CASE)

    def self.decode_entities_string(text : String) : String
      Markdown::HTMLEntities.decode_entities(text).gsub(DECODE_ENTITIES_REGEX) { |text| text[1].to_s }
    end
  end
end
