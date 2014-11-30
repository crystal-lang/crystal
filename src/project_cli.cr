require "project"

redefine_main do |main|
  begin
    {{main}}
  rescue ex : ProjectError
    puts ex.message
    exit 1
  end
  Project::INSTANCE.install_deps
end
