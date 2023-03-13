module Crystal::System::Signal
  # Sets the handler for this signal to the passed function.
  # def self.trap(signal, handler) : Nil

  # Resets the handler for this signal to the OS default.
  # def self.reset(signal) : Nil

  # Clears the handler for this signal and prevents the OS default action.
  # def self.ignore(signal) : Nil
end

{% if flag?(:wasi) %}
  require "./wasi/signal"
{% elsif flag?(:unix) %}
  require "./unix/signal"
{% elsif flag?(:win32) %}
  require "./win32/signal"
{% else %}
  {% raise "No Crystal::System::Signal implementation available" %}
{% end %}
