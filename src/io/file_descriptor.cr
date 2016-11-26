{% if flag?(:windows) %}
  require "./file_descriptor.windows.cr"
{% else %}
  require "./file_descriptor.posix.cr"
{% end %}
