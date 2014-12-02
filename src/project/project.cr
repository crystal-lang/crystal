require "json"
require "./*"

class Project
  INSTANCE = Project.new
  property dependencies

  def initialize
    @dependencies = [] of Dependency
  end

  def install_deps
    # Prepare required directories
    Dir.mkdir_p ".deps"
    Dir.mkdir_p "libs"

    # Load lockfile
    if File.file?(".deps.lock")
      lock = JSON.parse(File.read(".deps.lock")) as Hash
      @dependencies.each do |dep|
        if locked_version = lock[dep.name]?
          dep.locked_version = locked_version as String
        end
      end
    end

    # Install al dependencies
    @dependencies.each &.install

    # Save lockfile
    lock = {} of String => String
    @dependencies.each do |dep|
      lock[dep.name] = dep.locked_version.not_nil!
    end
    File.open(".deps.lock", "w") do |lock_file|
      lock.to_pretty_json(lock_file)
      lock_file.puts
    end
  end
end

class ProjectError < Exception
end
