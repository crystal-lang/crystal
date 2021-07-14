{% if flag?(:unix) %}
  require "./unix/group"
{% elsif flag?(:wasm32) %}
  require "./wasm/group"
{% else %}
  {% raise "No Crystal::System::Group implementation available" %}
{% end %}
