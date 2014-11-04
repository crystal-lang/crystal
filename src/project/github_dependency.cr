class GitHubDependency < Dependency
  def initialize(repo)
    unless repo =~ /(.*)\/(.*)/
      raise ProjectError.new("Invalid GitHub repository definition: #{repo}")
    end

    @author = $1
    @name = @repository = $2
    @target_dir = ".deps/#{@repository}"
  end

  def install
    unless Dir.exists?(@target_dir)
      `git clone https://github.com/#{@author}/#{@repository}.git #{@target_dir}`
    end
    `ln -sf ../#{@target_dir}/src libs/#{@repository}`

    if @locked_version &&
      if current_version != @locked_version
        `git -C #{@target_dir} checkout -q #{@locked_version}`
      end
    else
      @locked_version = current_version
    end
  end

  def current_version
    `git -C #{@target_dir} rev-parse HEAD`.chomp
  end
end
