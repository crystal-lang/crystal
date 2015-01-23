require "crystal/project/dependency"
require "crystal/project/project_error"

module Crystal
  class PathDependency < Dependency
    def initialize(@path, name = nil)
      unless @path =~ /(.*\/)*(.*)/
        raise ProjectError.new("Invalid path name: #{path}")
      end

      super(name || $2)
    end

    def target_dir
      "libs/#{name}"
    end

    def install
      unless Dir.exists?(@target_dir)
        exec "ln -sf ../#{@path}/src #{@target_dir}"
      end

      @locked_version = current_version
    end

    def update
      exec "rm -rf libs/#{@path}"
      install
    end

    def current_version
      exec("([ -d \"#{@path}/.git\" ] && git -C #{@path} rev-parse HEAD) || echo -n 'local'")
    end

    private def exec(cmd)
      result = `#{cmd}`
      unless $?.success?
        puts "Error executing command: #{cmd}"
        exit 1
      end
      result
    end
  end
end
