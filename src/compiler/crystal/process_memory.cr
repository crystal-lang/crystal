module Crystal
  # Reports how much memory the current process uses, as the operating system
  # accounts it: the physical footprint on macOS, the resident set size on
  # Linux and the working set on Windows. Unlike the GC heap statistics this
  # includes memory allocated outside the GC heap, such as LLVM's.
  module ProcessMemory
    {% if flag?(:darwin) %}
      lib LibProc
        RUSAGE_INFO_V4 = 4

        struct RusageInfoV4
          uuid : UInt8[16]
          user_time : UInt64
          system_time : UInt64
          pkg_idle_wkups : UInt64
          interrupt_wkups : UInt64
          pageins : UInt64
          wired_size : UInt64
          resident_size : UInt64
          phys_footprint : UInt64
          proc_start_abstime : UInt64
          proc_exit_abstime : UInt64
          child_user_time : UInt64
          child_system_time : UInt64
          child_pkg_idle_wkups : UInt64
          child_interrupt_wkups : UInt64
          child_pageins : UInt64
          child_elapsed_abstime : UInt64
          diskio_bytesread : UInt64
          diskio_byteswritten : UInt64
          cpu_time_qos_default : UInt64
          cpu_time_qos_maintenance : UInt64
          cpu_time_qos_background : UInt64
          cpu_time_qos_utility : UInt64
          cpu_time_qos_legacy : UInt64
          cpu_time_qos_user_initiated : UInt64
          cpu_time_qos_user_interactive : UInt64
          billed_system_time : UInt64
          serviced_system_time : UInt64
          logical_writes : UInt64
          lifetime_max_phys_footprint : UInt64
          instructions : UInt64
          cycles : UInt64
          billed_energy : UInt64
          serviced_energy : UInt64
          interval_max_phys_footprint : UInt64
          runnable_time : UInt64
        end

        fun proc_pid_rusage(pid : LibC::Int, flavor : LibC::Int, buffer : Void*) : LibC::Int
      end
    {% elsif flag?(:win32) %}
      lib LibPsapi
        struct ProcessMemoryCounters
          cb : LibC::DWORD
          page_fault_count : LibC::DWORD
          peak_working_set_size : LibC::SizeT
          working_set_size : LibC::SizeT
          quota_peak_paged_pool_usage : LibC::SizeT
          quota_paged_pool_usage : LibC::SizeT
          quota_peak_non_paged_pool_usage : LibC::SizeT
          quota_non_paged_pool_usage : LibC::SizeT
          pagefile_usage : LibC::SizeT
          peak_pagefile_usage : LibC::SizeT
        end

        # Exported by kernel32 since Windows 7, so no psapi import is needed.
        fun K32GetProcessMemoryInfo(process : LibC::HANDLE, counters : ProcessMemoryCounters*, cb : LibC::DWORD) : LibC::BOOL
      end
    {% end %}

    # Returns the memory the process uses in bytes, or `nil` where the
    # platform does not report it.
    def self.current : UInt64?
      {% if flag?(:darwin) %}
        info = uninitialized LibProc::RusageInfoV4
        if LibProc.proc_pid_rusage(LibC.getpid, LibProc::RUSAGE_INFO_V4, pointerof(info).as(Void*)) == 0
          info.phys_footprint
        end
      {% elsif flag?(:linux) %}
        File.each_line("/proc/self/status") do |line|
          if line.starts_with?("VmRSS:")
            return line[6..].strip.rchop("kB").strip.to_u64?.try &.*(1024)
          end
        end
        nil
      {% elsif flag?(:win32) %}
        counters = LibPsapi::ProcessMemoryCounters.new
        counters.cb = sizeof(LibPsapi::ProcessMemoryCounters)
        if LibPsapi.K32GetProcessMemoryInfo(LibC.GetCurrentProcess, pointerof(counters), counters.cb) != 0
          counters.working_set_size.to_u64
        end
      {% else %}
        nil
      {% end %}
    rescue IO::Error
      nil
    end
  end
end
