module Crystal::System::MIME
  # Load MIME types from operating system source.
  # def self.load
end

{% if flag?(:unix) %}
  require "./unix/mime"
{% elsif flag?(:win32) %}
  require "./win32/mime"
{% else %}
  {% raise "No Crystal::System::Mime implementation available" %}
{% end %}
