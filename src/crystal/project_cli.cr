require "./project"

project = Crystal::Project.new
begin
  project.eval do
    {{ `cat Projectfile 2> /dev/null || true` }}
  end

  command = ARGV.shift? || "install"

  case command
  when "install"
    project.install_deps
  when "update"
    project.update_deps ARGV
  else
    puts "Invalid command: #{command}"
  end
rescue ex : Crystal::ProjectError
  puts ex.message
  exit 1
end

