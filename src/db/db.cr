module DB
  TYPES = [String, Int32, Int64, Float32, Float64, Slice(UInt8)]
  alias Any = String | Int32 | Int64 | Float32 | Float64 | Slice(UInt8)

  def self.driver_class(name) # : Driver.class
    @@drivers.not_nil![name]
  end

  def self.register_driver(name, klass : Driver.class)
    @@drivers ||= {} of String => Driver.class
    @@drivers.not_nil![name] = klass
  end

  def self.open(name, options)
    Database.new(driver_class(name), options)
  end
end

require "./database"
require "./driver"
require "./statement"
require "./result_set"
