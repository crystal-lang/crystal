{% if flag?(:win32) %}
  require "./win32/file_descriptor"
{% else %}
  require "./unix/file_descriptor"
{% end %}
