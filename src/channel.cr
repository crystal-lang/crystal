require "fiber"

{% if flag?(:mt) %}
  require "concurrent/mt_channel"
{% else %}
  require "concurrent/st_channel"
{% end %}
