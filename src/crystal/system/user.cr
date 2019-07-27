{% if flag?(:unix) %}
  require "./unix/user"
{% else %}
  {% raise "No Crystal::System::User implementation available" %}
{% end %}
