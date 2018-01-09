lib LibC
  TCP_NODELAY     = 0x01 # don't delay send to coalesce pkts
  TCP_MAXSEG      = 0x02 # set maximum segment size
  TCP_MD5SIG      = 0x04 # enable TCP MD5 signature option
  TCP_SACK_ENABLE = 0x08 # enable SACKs (if disabled by def.)
  TCP_NOPUSH      = 0x10 # don't push last block of write
end
