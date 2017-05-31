{% if flag?(:windows) %}
  require "./file.windows.cr"
{% else %}
  require "./file.posix.cr"
  require "file/flock.posix.cr"
{% end %}

require "file/stat"
require "file/preader"
