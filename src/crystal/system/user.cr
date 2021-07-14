{% if flag?(:unix) %}
  require "./unix/user"
{% elsif flag?(:wasm32) %}
  require "./wasm/user"
{% else %}
  {% raise "No Crystal::System::User implementation available" %}
{% end %}
