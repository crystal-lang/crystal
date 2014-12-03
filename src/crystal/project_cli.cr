require "./project"

project = Crystal::Project.new
begin
  project.eval do
    {{ `cat Projectfile` }}
  end
rescue ex : Crystal::ProjectError
  puts ex.message
  exit 1
end

project.install_deps
