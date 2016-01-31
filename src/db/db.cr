module DB
  TYPES = [String, Int32, Int64, Float32, Float64, Slice(UInt8)]
  alias Any = String | Int32 | Int64 | Float32 | Float64 | Slice(UInt8)

  # :nodoc:
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

  def self.open(name, options, &block)
    open(name, options).tap do |db|
      yield db
      db.close
    end
  end
end

require "./query_methods"
require "./database"
require "./driver"
require "./connection"
require "./statement"
require "./result_set"
