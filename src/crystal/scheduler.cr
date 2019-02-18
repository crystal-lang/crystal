require "fiber"
require "thread"
require "./event_loop"

{% if flag?(:mt) %}
  require "../concurrent/mt_scheduler"
{% else %}
  require "../concurrent/st_scheduler"
{% end %}
