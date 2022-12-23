{% if flag?(:use_pcre2) %}
  require "./pcre2"

  # :nodoc:
  alias Regex::Engine = PCRE2
{% else %}
  require "./pcre"

  # :nodoc:
  alias Regex::Engine = PCRE
{% end %}
