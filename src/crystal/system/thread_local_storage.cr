{% if flag?(:win32) && flag?(:gnu) %}
  require "c/fibersapi"
{% end %}

# :nodoc:
class Thread
  # :nodoc:
  #
  # The GC can't access the local storage, so we must keep a pointer to the
  # table on the Thread local that is reachable for as long as the thread is
  # alive.
  #
  # We could spare this pointer if the table was uncollectible: the GC allocates
  # the memory, always scans it (even without explicit references) and never
  # collects it until it's explicitly told to be freed.
  protected property local_storage : LocalStorage?

  # :nodoc:
  class LocalStorage
    # FIXME: we should be able to use @[ThreadLocal] on every target: the
    # compiler needs to set the llvm::TargetOptions::EmulatedLTS option for
    # Android < 29, MinGW and OpenBSD, though mostly for overall consistency
    # since it might be set by default for some targets already.

    {% if flag?(:android) || flag?(:openbsd) %}
      @@key = uninitialized LibC::PthreadKeyT
      err = LibC.pthread_key_create(pointerof(@@key), nil)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0

      def self.local_table? : LocalStorage?
        ptr = LibC.pthread_getspecific(@@key)
        ptr.as(LocalStorage) unless ptr.null?
      end

      def self.local_table=(local_table : LocalStorage)
        err = LibC.pthread_setspecific(@@key, local_table.as(Void*))
        raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
        Thread.current.local_storage = local_table
      end
    {% elsif flag?(:win32) && flag?(:gnu) %}
      @@key = uninitialized LibC::DWORD
      @@key = LibC.FlsAlloc(nil)
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if @@key == LibC::FLS_OUT_OF_INDEXES

      def self.local_table? : LocalStorage?
        ptr = LibC.FlsGetValue(@@key)
        ptr.as(LocalStorage) unless ptr.null?
      end

      def self.local_table=(local_table : LocalStorage)
        ret = LibC.FlsSetValue(@@key, local_table.as(Void*))
        raise RuntimeError.from_winerror("FlsSetValue") if ret == 0
        Thread.current.local_storage = local_table
      end
    {% else %}
      @[ThreadLocal]
      @@local_table : LocalStorage?

      def self.local_table? : LocalStorage?
        @@local_table
      end

      def self.local_table=(@@local_table : LocalStorage)
        Thread.current.local_storage = local_table
      end
    {% end %}

    def self.local_table : LocalStorage
      local_table? || self.local_table = LocalStorage.new
    end

    def finalize
      {% for var, index in @type.class_vars %}
        {% if var.name.starts_with?("__destructor") %}
          @@{{var.name}}.call(self) rescue nil
        {% end %}
      {% end %}
    end
  end

  macro thread_local(decl, destructor = nil)
    {% raise "Expected TypeDeclaration" unless decl.is_a?(TypeDeclaration) %}

    protected def self.{{decl.var.id}}(&block : -> {{decl.type}}) : {{decl.type}}
      table = ::Thread::LocalStorage.local_table
      if (value = table.%var).nil?
        table.%var = yield
      else
        value
      end
    end

    class ::Thread::LocalStorage
      property %var : {{decl.type}} | Nil

      {% if destructor %}
        @@__destructor%var : Proc(self, Nil) = ->(table : self) {
          if value = table.%var
            {{destructor}}.call(value)
          end
          nil
        }
      {% end %}
    end
  end
end
