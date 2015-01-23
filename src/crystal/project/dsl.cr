struct Crystal::Project::DSL
  def initialize(@project)
  end

  def deps
    with Deps.new(@project) yield
  end

  struct Deps
    def initialize(@project)
    end

    def github(repository, name = nil : String)
      @project.dependencies << GitHubDependency.new(repository, name)
    end

    def local(path, name = nil : String)
      @project.dependencies << LocalDependency.new(path, name)
    end
  end
end
