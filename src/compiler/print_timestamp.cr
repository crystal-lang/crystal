require "time"

if ARGV == ["compiler/print_timestamp"] # In case this file is accidentally included
  print Time.utc.to_unix
end
