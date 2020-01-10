require "spec"
{% unless flag?(:win32) %}
  require "./std/**"
{% else %}
  # This list gives an overview over which specs are currently working on win32.
  #
  # See spec/generate_windows_spec.sh for details.
  require "./win32_std_spec.cr"
{% end %}
