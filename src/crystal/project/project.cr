require "json"
require "crystal/project/project_error"

class Crystal::Project
  property dependencies

  def initialize
    @dependencies = [] of Dependency
  end

  def eval
    with DSL.new(self) yield
  end

  def install_deps
    prepare_required_directories

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

    save_lockfile
  end

  def update_deps(deps)
    prepare_required_directories

    deps = dependencies.map &.name if deps.empty?
    deps.each do |dep_name|
      find_dependency(dep_name).update
    end

    save_lockfile
  end

  def prepare_required_directories
    Dir.mkdir_p ".deps"
    Dir.mkdir_p "libs"
  end

  def save_lockfile
    lock = {} of String => String
    @dependencies.each do |dep|
      lock[dep.name] = dep.locked_version.not_nil!
    end
    File.open(".deps.lock", "w") do |lock_file|
      lock.to_pretty_json(lock_file)
      lock_file.puts
    end
  end

  def find_dependency(name)
    @dependencies.find { |dep| dep.name == name } ||
      raise ProjectError.new("Could not find dependency '#{name}'")
  end
end

require "./*"
