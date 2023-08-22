require "./mappings/*"

module Markd::HTMLEntities
  module ExtendToHTML
    def decode_entities(source : String)
      Decoder.decode(source)
    end

    def decode_entity(source : String)
      Decoder.decode_entity(source)
    end

    def encode_entities(source)
      Encoder.encode(source)
    end
  end

  module Decoder
    REGEX = /&(?:([a-zA-Z0-9]{2,32};)|(#[xX][\da-fA-F]+;?|#\d+;?))/

    def self.decode(source)
      source.gsub(REGEX) do |chars|
        decode_entity(chars[1..-2])
      end
    end

    def self.decode_entity(chars)
      if chars[0] == '#'
        if chars.size > 1
          if chars[1].downcase == 'x'
            if chars.size > 2
              return decode_codepoint(chars[2..-1].to_i(16))
            end
          else
            return decode_codepoint(chars[1..-1].to_i(10))
          end
        end
      else
        entities_key = chars[0..-1]
        if resolved_entity = Markd::HTMLEntities::ENTITIES_MAPPINGS[entities_key]?
          return resolved_entity
        end
      end

      "&#{chars};"
    end

    def self.decode_codepoint(codepoint)
      return "\uFFFD" if codepoint >= 0xD800 && codepoint <= 0xDFFF || codepoint > 0x10FFF

      if decoded = Markd::HTMLEntities::DECODE_MAPPINGS[codepoint]?
        codepoint = decoded
      end

      codepoint.unsafe_chr
    end
  end

  module Encoder
    ENTITIES_REGEX = Regex.union(HTMLEntities::ENTITIES_MAPPINGS.values)
    ASTRAL_REGEX   = Regex.new("[\xED\xA0\x80-\xED\xAF\xBF][\xED\xB0\x80-\xED\xBF\xBF]")
    ENCODE_REGEX   = /[^\x{20}-\x{7E}]/

    def self.encode(source : String)
      source.gsub(ENTITIES_REGEX) { |chars| encode_entities(chars) }
        .gsub(ASTRAL_REGEX) { |chars| encode_astral(chars) }
        .gsub(ENCODE_REGEX) { |chars| encode_extend(chars) }
    end

    private def self.encode_entities(chars : String)
      entity = HTMLEntities::ENTITIES_MAPPINGS.key(chars)
      "&#{entity};"
    end

    private def self.encode_astral(chars : String)
      high = chars.char_at(0).ord
      low = chars.char_at(0).ord
      codepoint = (high - 0xD800) * -0x400 + low - 0xDC00 + 0x10000

      "&#x#{codepoint.to_s(16).upcase};"
    end

    private def self.encode_extend(char : String)
      "&#x#{char[0].ord.to_s(16).upcase};"
    end
  end
end

module HTML
  extend Markd::HTMLEntities::ExtendToHTML
end
