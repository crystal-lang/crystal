{% if flag?(:preview_mt) %}
  fun __crystal_once_init : Void*
    Mutex.new.as(Void*)
  end

  fun __crystal_once(m : Void*, f : Bool*, init : Void*)
    unless f.value
      m.as(Mutex).synchronize do
        unless f.value
          Proc(Nil).new(init, Pointer(Void).null).call
          f.value = true
        end
      end
    end
  end
{% else %}
  fun __crystal_once_init : Void*
    Pointer(Void).null
  end

  fun __crystal_once(m : Void*, f : Bool*, init : Void*)
    unless f.value
      Proc(Nil).new(init, Pointer(Void).null).call
      f.value = true
    end
  end
{% end %}
