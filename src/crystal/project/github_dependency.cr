require "crystal/project/dependency"
require "crystal/project/project_error"

module Crystal
  class GitHubDependency < Dependency
    getter target_dir

    def initialize(repo, name = nil : String?)
      unless repo =~ /(.*)\/(.*)/
        raise ProjectError.new("Invalid GitHub repository definition: #{repo}")
      end

      @author = $1
      @repository = $2
      @target_dir = ".deps/#{@author}-#{@repository}"

      super(name || @repository)
    end

    def install
      unless Dir.exists?(target_dir)
        exec "git clone git://github.com/#{@author}/#{@repository}.git #{target_dir}"
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
