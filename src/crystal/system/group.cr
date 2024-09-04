module Crystal::System::Group
  # def system_name : String

  # def system_id : String

  # def self.from_name?(groupname : String) : ::System::Group?

  # def self.from_id?(groupid : String) : ::System::Group?
end

{% if flag?(:wasi) %}
  require "./wasi/group"
{% elsif flag?(:unix) %}
  require "./unix/group"
{% else %}
  {% raise "No Crystal::System::Group implementation available" %}
{% end %}
