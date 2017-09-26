{% if flag?(:linux) %}
  require "./unix/getrandom"
{% elsif flag?(:openbsd) %}
  require "./unix/arc4random"
{% else %}
  # TODO: restrict on flag?(:unix) after crystal > 0.22.0 is released
  require "./unix/urandom"
{% end %}
