require "socket"

@[Link("uv")]
lib LibUV
  type Loop = Void*

  enum RunMode
    DEFAULT = 0
    ONCE
    NOWAIT
  end

  enum HandleType
    UNKNOWN = 0
  end

  struct Handle
    data : Void*
    loop : Loop
    type : HandleType

    close_cb : Void*
    handle_queue : Void*[2]
    reserved : Void*[4]
    next_closing : Handle*
    flags : UInt32
  end

  struct Timer
    handle : Handle

    timer_cb : Void*
    heap_node : Void*[3]
    timeout : UInt64
    repeat : UInt64
    start_id : UInt64
  end

  struct IO
    cb : Void*;
    pending_queue : Void*[2]
    watcher_queue : Void*[2]
    pevents : UInt32
    events : UInt32
    fd : Int32

    ifdef darwin
      rcount : Int32
      wcount : Int32
    end
  end

  struct Stream
    include Handle
    write_queue_size : LibC::SizeT
    alloc_cb : Void*
    read_cb : Void*

    connect_req : Void*
    shutdown_req : Void*
    io_watcher : IO
    write_queue : Void*[2]
    write_completed_queue : Void*[2]
    connection_cb : Void*
    delayed_error : Int32
    accepted_fd : Int32
    queued_fds : Void*

    ifdef darwin
      select : Void*
    end
  end

  struct Tcp
    include Stream
  end

  struct Req
    data : Void*
    type : Int32
    active_queue : Void*[2]
    reserved : Void*[4]
  end

  struct Connect
    include Req
    cb : Void*
    handle : Stream*
    queue : Void*[2]
  end

  struct Buf
    base : Void*
    len : LibC::SizeT
  end

  struct Write
    include Req
    cb : Void*
    send_handle : Stream*
    handle : Stream*

    queue : Void*[2]
    write_index : UInt32
    bufs : Buf*
    nbufs : UInt32
    error : Int32
    bufsml : Buf[4]
  end

  struct Work
    work : Void*
    done : Void*
    loop : Loop*
    wq : Void*[2]
  end

  struct GetAddrInfoReq
    include Req
    loop : Loop*
    work_req : Work
    cb : Void*
    hints : LibC::Addrinfo*
    hostname : UInt8*
    service : UInt8*
    res : LibC::Addrinfo*
    retcode : Int32
  end

  type CloseCallback = (Handle*) ->
  type TimerCallback = (Timer*, Int32) ->
  type AllocCallback = (Handle*, LibC::SizeT, Buf*) ->
  type ReadCallback = (Stream*, LibC::SSizeT, Buf*) ->
  type WriteCallback = (Write*, Int32) ->
  type ConnectCallback = (Connect*, Int32) ->
  type GetAddrInfoCallback = (GetAddrInfoReq*, Int32, LibC::Addrinfo*) ->
  type ConnectionCallback = (Stream*, Int32) ->

  fun close = uv_close(Handle*, CloseCallback)

  fun timer_init = uv_timer_init(Loop, Timer*)
  fun timer_start = uv_timer_start(t : Timer*, cb : TimerCallback, timeout : UInt64, repeat : UInt64) : Int32
  fun timer_stop = uv_timer_stop(Timer*) : Int32
  fun timer_again = uv_timer_again(Timer*) : Int32

  fun read_start = uv_read_start(Stream*, AllocCallback, ReadCallback) : Int32
  fun read_stop = uv_read_stop(Stream*) : Int32
  fun write = uv_write(Write*, Stream*, Buf*, UInt32, WriteCallback) : Int32
  fun listen = uv_listen(Stream*, Int32, ConnectionCallback) : Int32
  fun accept = uv_accept(server : Stream*, client : Stream*) : Int32

  fun tcp_init = uv_tcp_init(Loop, Tcp*) : Int32
  fun tcp_connect = uv_tcp_connect(Connect*, Tcp*, LibC::SockAddr*, ConnectCallback) : Int32
  fun tcp_bind = uv_tcp_bind(Tcp*, LibC::SockAddr*, Int32) : Int32

  fun getaddrinfo = uv_getaddrinfo(loop : Loop, req : GetAddrInfoReq*, cb : GetAddrInfoCallback, node : UInt8*,
                                    service : UInt8*, hints : LibC::Addrinfo*) : Int32
  fun freeaddrinfo = uv_freeaddrinfo(LibC::Addrinfo*)

  fun loop_new = uv_loop_new : Loop
  fun default_loop = uv_default_loop : Loop
  fun run = uv_run(Loop, RunMode) : Int32
end
