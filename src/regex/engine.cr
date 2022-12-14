{% if flag?(:force_pcre2) || (!flag?(:force_pcre) && !flag?(:win32) && `hash pkg-config 2> /dev/null && pkg-config --silence-errors --modversion libpcre2-8 || printf %s false` != "false") %}
  require "./pcre2"

  # :nodoc:
  alias Regex::Engine = PCRE2
{% else %}
  require "./pcre"

  # :nodoc:
  alias Regex::Engine = PCRE
{% end %}
