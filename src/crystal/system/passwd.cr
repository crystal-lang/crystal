{% if flag?(:unix) %}
  require "./unix/passwd"
{% else %}
  {% raise "No Crystal::System::Passwd implementation available" %}
{% end %}
