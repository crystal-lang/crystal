{% if flag?(:windows) %}
  require "./scheduler.windows.cr"
{% else %}
  require "./scheduler.posix.cr"
{% end %}
