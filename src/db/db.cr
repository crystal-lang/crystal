module DB
  def self.driver_class(name) # : Driver.class
    @@drivers.not_nil![name]
  end

  def self.register_driver(name, klass : Driver.class)
    @@drivers ||= {} of String => Driver.class
    @@drivers.not_nil![name] = klass
  end

  def self.driver(name, options)
    driver_class(name).new(options)
  end
end

require "./driver"
