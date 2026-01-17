module Crystal::System::Env
  # Sets an environment variable or unsets it if *value* is `nil`.
  # def self.set(key : String, value : String?) : Nil

  # Gets an environment variable.
  # def self.get(key : String) : String?

  # Reads the environment variables into a hash.
  # def self.parse : Array({String, String})

  # Compares keys and returns true if equal.
  # Calls `String#==` by default.
  def self.equal?(a : String, b : String) : Bool
    a == b
  end
end

{% if flag?(:unix) %}
  require "./unix/env"
{% elsif flag?(:win32) %}
  require "./win32/env"
{% else %}
  {% raise "No Crystal::System::Env implementation available" %}
{% end %}
