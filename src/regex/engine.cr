# PCRE2 is the default regex engine and should always be preferred.
# The legacy PCRE engine is still supported for compatibility reasons, but it is
# opt-in via compiler flag `-Duse_pcre` or env var `USE_PCRE1`.
{% unless flag?(:use_pcre) || !(env("USE_PCRE1") || "").empty? %}
  require "./pcre2"

  # :nodoc:
  alias Regex::Engine = PCRE2
{% else %}
  require "./pcre"

  # :nodoc:
  alias Regex::Engine = PCRE
{% end %}
