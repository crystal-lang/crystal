{% if flag?(:unix) %}
  require "./unix/process"
{% else %}
  {% raise "No Crystal::Process implementation available" %}
{% end %}
