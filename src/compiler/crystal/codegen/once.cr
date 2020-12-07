require "./codegen"

class Crystal::CodeGenVisitor
  ONCE_STATE = "~ONCE_STATE"

  def once_init
    if once_init_fun = @main_mod.functions[ONCE_INIT]?
      once_init_fun = check_main_fun ONCE_INIT, once_init_fun

      once_state_global = @main_mod.globals.add(once_init_fun.return_type, ONCE_STATE)
      once_state_global.linkage = LLVM::Linkage::Internal if @single_module
      once_state_global.initializer = once_init_fun.return_type.null

      state = call once_init_fun
      store state, once_state_global
    end
  end

  def run_once(flag, func)
    once_fun = main_fun(ONCE)

    once_state_global = @llvm_mod.globals[ONCE_STATE]? || begin
      once_init_fun = main_fun(ONCE_INIT)
      global = @llvm_mod.globals.add(once_init_fun.return_type, ONCE_STATE)
      global.linkage = LLVM::Linkage::External
      global
    end

    call main_fun(ONCE), [
      load(once_state_global),
      flag,
      bit_cast(func.to_value, once_fun.params.last.type),
    ]
  end
end
