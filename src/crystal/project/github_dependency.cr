require "crystal/project/dependency"
require "crystal/project/project_error"

module Crystal
  class GitHubDependency < Dependency
    getter target_dir

    def initialize(repo, name = nil : String?, ssh = false, branch = nil : String?)
      unless repo =~ /(\A[^\s\/]+)\/([^\s\/]+\z)/
        raise ProjectError.new("Invalid GitHub repository definition: #{repo}")
      end

      @author = $1
      @repository = $2
      @target_dir = ".deps/#{@author}-#{@repository}"
      @branch = " -b #{branch}" if branch
      @use_ssh = ssh

      super(name || @repository)
    end

    def install
      unless Dir.exists?(target_dir)
        repo_url = if @use_ssh
          "git@github.com:#{@author}/#{@repository}.git"
        else
          "git://github.com/#{@author}/#{@repository}.git"
        end

        exec "git clone#{@branch} #{repo_url} #{target_dir}"
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
