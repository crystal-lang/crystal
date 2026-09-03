module Crystal::System::User
  # def system_username : String

  # def system_id : String

  # def system_group_id : String

  # def system_name : String

  # def system_home_directory : String

  # def system_shell : String

  # def self.from_username?(username : String) : ::System::User?

  # def self.from_id?(id : String) : ::System::User?
end

{% if flag?(:wasi) %}
  require "./wasi/user"
{% elsif flag?(:unix) %}
  require "./unix/user"
{% elsif flag?(:win32) %}
  require "./win32/user"
{% else %}
  {% raise "No Crystal::System::User implementation available" %}
{% end %}
