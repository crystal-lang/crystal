require "./thread/*"

{% if flag?(:windows) %}
  require "./thread.windows.cr"
{% else %}
  require "./thread.posix.cr"
{% end %}
