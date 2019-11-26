{% if flag?(:unix) %}
  require "./unix/process"
{% elsif flag?(:win32) %}
  require "./win32/process"
{% else %}
  {% raise "No Crystal::Process implementation available" %}
{% end %}
