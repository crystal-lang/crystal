class Project
  class DSL::Deps
    def initialize(@project)
    end

    def github(repository, name = nil : String)
      @project.dependencies << GitHubDependency.new(repository, name)
    end
  end
end

def deps
  with Project::DSL::Deps.new(Project::INSTANCE) yield
end
