module Crystal
  module ClosureContext
    def closured_vars?
      @closured_vars
    end

    def closured_vars
      @closured_vars ||= [] of Var
    end
  end
end
