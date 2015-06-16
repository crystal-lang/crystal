require "crystal/project/dependency"
require "crystal/project/project_error"
require "crystal/project/git_dependency"

module Crystal
  class GitHubDependency < GitDependency
    getter target_dir

    def initialize(repo, name = nil : String?, ssh = false, branch = nil : String?)
      unless repo =~ /(.*)\/(.*)/
        raise ProjectError.new("Invalid GitHub repository definition: #{repo}")
      end

      repository = $2

      repo_url = if ssh
        "git@github.com:#{repo}.git"
      else
        "git://github.com/#{repo}.git"
      end

      super(repo_url, name || repository, branch)
    end
  end
end
