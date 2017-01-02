{% if flag?(:windows) %}
  require "./stat.windows.cr"
{% else %}
  require "./stat.posix.cr"
{% end %}
