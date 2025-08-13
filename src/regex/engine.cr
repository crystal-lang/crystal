# The following condition ensures that the engine selection respects `-Duse_pcre2`/`-Duse_pcre`,
# and if none is given it tries to check for availability of `libpcre2` with `pkg-config`.
# If `pkg-config` is unavailable, the default is PCRE2. If `pkg-config` is available but
# has no information about a `libpcre2` package, it falls back to PCRE.
{% if flag?(:use_pcre2) || (!flag?(:use_pcre) && (flag?(:win32) || `hash pkg-config 2> /dev/null && (pkg-config --silence-errors --modversion libpcre2-8 || printf %s false) || true` != "false")) %}
  require "./pcre2"

  # :nodoc:
  alias Regex::Engine = PCRE2
{% else %}
  require "./pcre"

  # :nodoc:
  alias Regex::Engine = PCRE
{% end %}
