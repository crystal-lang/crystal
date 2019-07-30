{% if flag?(:unix) %}
  require "./unix/group"
{% else %}
  {% raise "No Crystal::System::Group implementation available" %}
{% end %}
