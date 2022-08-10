struct Int
  def to_xml(xml : XML::Builder) : Nil
    xml.text(self.to_s)
  end

  def to_xml_object_key : String
    to_s
  end
end

struct Nil
  def to_xml(xml : XML::Builder) : Nil
    xml.text("")
  end

  def to_xml_object_key : String
    ""
  end
end

class String
  def to_xml(xml : XML::Builder) : Nil
    xml.text(self)
  end

  def to_xml_object_key : String
    self
  end
end

struct Bool
  def to_xml(xml : XML::Builder) : Nil
    xml.text(self.to_s)
  end
end

class Hash
  # Serializes this Hash into XML.
  #
  # Keys are serialized by invoking `to_xml_object_key` on them.
  # Values are serialized with the usual `to_xml(xml : XML::Node)`
  # method.
  def to_xml(name : String, xml : XML::Builder) : Nil
    xml.element(name) do
      each do |key, value|
        xml.element(key) do
          value.to_xml(value, xml)
        end
      end
    end
  end
end

struct Time::Format
  def to_xml(value : Time, xml : XML::Builder) : Nil
    format(value).to_xml(xml)
  end
end

# Converter to be used with `XML::Serializable` and `YAML::Serializable`
# to serialize a `Time` instance as the number of seconds
# since the unix epoch. See `Time#to_unix`.
# ```
module Time::EpochConverter
  def self.to_xml(value : Time, xml : XML::Builder) : Nil
    xml.text(value.to_unix.to_s)
  end
end

# Converter to be used with `XML::Serializable` and `YAML::Serializable`
# to serialize a `Time` instance as the number of milliseconds
# since the unix epoch. See `Time#to_unix_ms`.
module Time::EpochMillisConverter
  def self.to_xml(value : Time, xml : XML::Builder) : Nil
    xml.text(value.to_unix_ms.to_s)
  end
end

# Converter to be used with `XML::Serializable` to read the raw
# value of a XML object property as a `String`.
#
# It can be useful to read ints and floats without losing precision,
# or to read an object and deserialize it later based on some
# condition.
module String::RawConverter
  def self.to_xml(value : String, xml : XML::Builder) : Nil
    xml.text(value.to_s)
  end
end
