#!/usr/bin/env ruby

# Lightweight library to access the System V message queue functionality on Mac OS X (32 and 64 bit)
# Still quite scrappy and needs to be packaged up properly but.. it works!

require 'fiddle'
class MsgQ
  LIBC = Fiddle.dlopen('libc.dylib')
  
  IPC_CREAT  = 001000
  IPC_EXCL   = 002000
  IPC_NOWAIT = 004000
  IPC_R      = 000400
  IPC_W      = 000200
  IPC_M      = 010000
  
  SIZEOF_LONG = [0].pack('L_').size
  
  def initialize(path, id)
    @id = self.class.get(path, id)
  end
  
  def self.ftok(path, id)
    id = id.class == String ? id.ord : id.to_i
    Fiddle::Function.new(LIBC['ftok'], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT).call(path, id)
  end

  def self.get(path, id, msgflag = IPC_CREAT | IPC_R | IPC_W | IPC_M )
    Fiddle::Function.new(LIBC['msgget'], [Fiddle::TYPE_INT, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
                    .call(ftok(path, id), msgflag)
  end

  def send(msg = {}, flags = 0)
    msg = { msg: msg } if msg.is_a? String
    msg = { type: 1, msg: '' }.merge(msg)
    
    r = Fiddle::Function.new(LIBC['msgsnd'], [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
                    .call(@id, [msg[:type]].pack('Q') + msg[:msg], msg[:msg].length + 1, flags)
                    
    r == -1 ? false : r
  end

  def receive(size, type, flags)
    #ptr = Fiddle::CPtr.malloc(size + SIZEOF_LONG)
    ptr = Fiddle::Pointer.malloc(size + SIZEOF_LONG)
    r = Fiddle::Function.new(LIBC['msgrcv'], [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
                        .call(@id, ptr.to_i, size, type, flags)
    msg_type = ptr[0, SIZEOF_LONG].unpack('Q')[0]
    msg = (ptr + SIZEOF_LONG).to_s
    ptr.free
    r == -1 ? false : { type: msg_type, msg: msg }
  end
end

###

if __FILE__ == $0
  queue = MsgQ.new('/tmp', 'A')
  queue.send type: 2, msg: "test"
  queue.send type: 3, msg: "test"
  queue.send type: 4, msg: "test"
  queue.send "test"

  while m = queue.receive(5, 0, MsgQ::IPC_NOWAIT)
    p m
  end
end
