#!/usr/bin/env ruby

# Lightweight library to access the System V message queue functionality on Mac OS X (32 and 64 bit)
# Still quite scrappy and needs to be packaged up properly but.. it works!

require 'fiddle'
class MsgQ
  _tmp_receive_type = Hash.new { |hash, key| key }
  _tmp_receive_type[:first_thing_in_the_queue] = 0
  RECEIVE_TYPE = _tmp_receive_type.freeze

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

if __FILE__ == $PROGRAM_NAME
  require "optparse"
  program_name = File.basename(__FILE__, ".*")
  server_id = 'Q_ID_A'
  message = ""
  message_type = ""
  max_message_length = 255
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: ./#{program_name}.rb [OPTIONS]..."

    opts.on("-r", "--receive", "Receive message") do
      message = ""
    end

    opts.on("-s [MESSAGE]", "--send [MESSAGE]", "Send message") do |msg|
      message = msg
    end

    opts.on("-m [MAX_MESSAGE_LENGTH]", "--max_length [MAX_MESSAGE_LENGTH]", "Max Message Length") do |len|
      max_message_length = len.to_i
    end

    opts.on("-t [TYPE]", "--type [TYPE]", "Message Type") do |type_id|
      message_type = type_id.to_i
    end

    opts.on("-i [ID]", "--id [ID]", "Server ID") do |s_id|
      server_id = s_id
    end
    opts.on_tail("-h", "--help", "This help screen" ) do
      puts opts
      puts %Q(\n    e.g. ./#{program_name}.rb --send "hey how's it going?"; ./#{program_name}.rb --receive)
      exit
    end
  end
  opt_parser.parse!

  queue = MsgQ.new('/tmp', server_id)
  message.empty? ? p(queue.receive(max_message_length, MsgQ::RECEIVE_TYPE[:first_thing_in_the_queue], MsgQ::IPC_NOWAIT)) : (message_type.empty? ? queue.send(message) : queue.send(type: message_type, msg: message))
end
