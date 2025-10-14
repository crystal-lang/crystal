{% if flag?(:preview_mt) %}
  require "./fd_lock_mt"
{% else %}
  require "./fd_lock_no_mt"
{% end %}
