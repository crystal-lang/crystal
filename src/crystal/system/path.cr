module Crystal::System::Path
  # Returns the path of the home directory of the current user.
  # def self.home : String
end

{% if flag?(:wasi) %}
  require "./wasi/path"
{% elsif flag?(:unix) %}
  require "./unix/path"
{% elsif flag?(:win32) %}
  require "./win32/path"
{% else %}
  {% raise "No Crystal::System::Path implementation available" %}
{% end %}
