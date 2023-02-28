{% if flag?(:win32) %}
  require "signal/win32"
{% else %}
  require "signal/unix"
{% end %}
