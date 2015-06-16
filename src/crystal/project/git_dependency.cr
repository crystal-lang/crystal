require "crystal/project/dependency"
require "crystal/project/project_error"

module Crystal
  class GitDependency < Dependency
    getter target_dir

    def initialize(@repo, name = nil : String?, branch = nil : String?)
      unless repo =~ /(.*)(:|\/)(.*)\/(.*)(.git)/
        raise ProjectError.new("Invalid Git repository definition: #{repo}")
      end

      @author = $3
      @repository = $4
      @target_dir = ".deps/#{@author}-#{@repository}"
      @branch = if branch
        "-b #{branch}"
      else
        ""
      end

      super(name || @repository)
    end

    def install
      unless Dir.exists?(target_dir)
        exec "git clone #{@branch} #{@repo} #{@target_dir}"
      end

      exec "ln -sf ../#{target_dir}/src libs/#{name}"

      if @locked_version
        if current_version != @locked_version
          exec "git -C #{target_dir} checkout -q #{@locked_version}"
        end
      else
        @locked_version = current_version
      end
    end

    def update
      exec "rm -rf #{target_dir}"
      @locked_version = nil
      install
    end

    def current_version
      exec("git -C #{target_dir} rev-parse HEAD").chomp
    end

    protected def exec(cmd)
      result = `#{cmd}`
      unless $?.success?
        puts "Error executing command: #{cmd}"
        exit 1
      end
      result
    end
  end
end