module Crystal::System::Env
  # Sets an environment variable or unsets it if *value* is `nil`.
  # def self.set(key : String, value : String?) : Nil

  # Gets an environment variable.
  # def self.get(key : String) : String?

  # Returns `true` if environment variable is set.
  # def self.has_key?(key : String) : Bool

  # Iterates all environment variables.
  # def self.each(&block : String, String ->)
end

{% if flag?(:unix) %}
  require "./unix/env"
{% elsif flag?(:win32) %}
  require "./win32/env"
{% else %}
  {% raise "No Crystal::System::Env implementation available" %}
{% end %}
