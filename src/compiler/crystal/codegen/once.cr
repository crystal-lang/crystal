require "./codegen"

class Crystal::CodeGenVisitor
  ONCE_STATE = "~ONCE_STATE"

  def once_init
    if once_init_fun = typed_fun?(@main_mod, ONCE_INIT)
      once_init_fun = check_main_fun ONCE_INIT, once_init_fun

      once_state_global = @main_mod.globals.add(once_init_fun.type.return_type, ONCE_STATE)
      once_state_global.linkage = LLVM::Linkage::Internal if @single_module
      once_state_global.initializer = once_init_fun.type.return_type.null

      state = call once_init_fun
      store state, once_state_global
    end
  end

  def run_once(flag, func : LLVMTypedFunction)
    once_fun = main_fun(ONCE)
    once_init_fun = main_fun(ONCE_INIT)

    once_state_global = @llvm_mod.globals[ONCE_STATE]? || begin
      global = @llvm_mod.globals.add(once_init_fun.type.return_type, ONCE_STATE)
      global.linkage = LLVM::Linkage::External
      global
    end

    call once_fun, [
      load(once_init_fun.type.return_type, once_state_global),
      flag,
      bit_cast(func.func.to_value, once_fun.func.params.last.type),
    ]
  end
end
