module Crystal
  class LocalDependency < Dependency
    def initialize(@path, name = nil)
      unless @path =~ /(.*\/)*(.*)/
        raise ProjectError.new("Invalid path name: #{path}")
      end

      @name = name || $2

      unless @name
        case @directory_name
        when /^crystal($:_|-)(.*)$/
          @name = $1
        when /^(.*)(?:_|-)crystal$/
          @name = $1
        when /^(.*)\.cr$/
          @name = $1
        end
      end

      @target_dir = "libs/#{@name}"
    end

    def install
      unless Dir.exists?(@target_dir)
        exec "ln -sf #{@path} #{@target_dir}"
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
