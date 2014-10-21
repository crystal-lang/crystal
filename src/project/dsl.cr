class Project
  class DSL::Deps
    def initialize(@project)
    end

    def github(repository)
      @project.dependencies << GitHubDependency.new(repository)
    end
  end
end

def deps
  with Project::DSL::Deps.new(Project::INSTANCE) yield
end
