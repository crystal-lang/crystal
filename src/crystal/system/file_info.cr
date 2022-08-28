# :nodoc:
module Crystal::System::FileInfo
  # Size of the file, in bytes.
  # def system_size : Int64

  # The permissions of the file.
  # def system_permissions : Permissions

  # The type of the file.
  # def system_type : Type

  # The special flags this file has set.
  # def system_flags : Flags

  # The last time this file was modified.
  # def system_modification_time : Time

  # The user ID that the file belongs to.
  # def system_owner_id : String

  # The group ID that the file belongs to.
  # def system_group_id : String

  # Returns true if this `FileInfo` and *other* are of the same file.
  # def system_same_file?(other : self) : Bool
end

{% if flag?(:unix) %}
  require "./unix/file_info"
{% elsif flag?(:win32) %}
  require "./win32/file_info"
{% else %}
  {% raise "No Crystal::System::FileInfo implementation available" %}
{% end %}
