module Crystal::System::MIME
  # Load MIME types from operating system source.
  # def self.load
end

{% if flag?(:unix) %}
  require "./unix/mime"
{% elsif flag?(:win32) %}
  require "./win32/mime"
{% elsif flag?(:wasm32) %}
  require "./wasm/mime"
{% else %}
  {% raise "No Crystal::System::Mime implementation available" %}
{% end %}
