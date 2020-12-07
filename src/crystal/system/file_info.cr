{% if flag?(:unix) %}
  require "./unix/file_info"
{% elsif flag?(:win32) %}
  require "./win32/file_info"
{% else %}
  {% raise "No Crystal::System::File implementation available" %}
{% end %}
