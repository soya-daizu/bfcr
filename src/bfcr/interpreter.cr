require "./command"
require "./translator"

class Interpreter
  def initialize(text : String, optimize : Bool)
    instructions = text.gsub(/[^\[\]<>+\-,\.]/, "").chars
    @commands = Translator.translate_program(instructions, optimize)
  end

  def run
    memory = Pointer(UInt8).malloc(30000, 0_u8)
    pc = 0
    dataptr = 0
    stdout_buffer = IO::Memory.new(256)

    commands_size = @commands.size
    while pc < commands_size
      command = @commands[pc]
      case command.type
      when .inc_ptr?
        dataptr += command.arg
      when .inc_data?
        memory[dataptr] &+= command.arg
      when .read_stdin?
        command.arg.times do
          memory[dataptr] = gets(1).try(&.byte_at?(0)) || 0_u8
        end
      when .write_stdout?
        chr = memory[dataptr].chr
        command.arg.times do
          stdout_buffer << chr

          if chr == '\n'
            print stdout_buffer.to_s
            stdout_buffer.clear
          end
        end
      when .clear?
        memory[dataptr] = 0
      when .scan?
        until memory[dataptr] == 0
          dataptr += command.arg
        end
      when .multiply?
        if memory[dataptr] != 0
          destptr = dataptr + command.arg
          memory[destptr] &+= memory[dataptr] * command.arg2
          memory[dataptr] = 0
        end
      when .jump_if_data_zero?
        pc = command.arg if memory[dataptr] == 0
      when .jump_if_data_not_zero?
        pc = command.arg if memory[dataptr] != 0
      else
        raise "Invalid command encountered on pc=#{pc}"
      end

      pc += 1
    end

    print stdout_buffer.to_s if !stdout_buffer.empty?
  end
end
