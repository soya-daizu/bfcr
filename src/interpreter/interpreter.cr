require "./bytecode"
require "./translator"

class Interpreter
  def initialize(text : String, optimize : Bool)
    instructions = [] of Char

    text.each_char do |char|
      instructions.push(char) if "[]<>+-,.".includes?(char)
    end

    @bytecodes = Translator.translate_program(instructions, optimize)
  end

  def run
    memory = Array.new(30000, 0_u8)
    pc = 0
    dataptr = 0
    stdout_buffer = IO::Memory.new(256)

    bytecodes_size = @bytecodes.size
    while pc < bytecodes_size
      bytecode = @bytecodes[pc]
      case bytecode.type
      when .inc_ptr?
        dataptr += bytecode.arg
      when .inc_data?
        memory[dataptr] &+= bytecode.arg
      when .read_stdin?
        bytecode.arg.times do
          memory[dataptr] = gets(1).not_nil!.byte_at(0)
        end
      when .write_stdout?
        chr = memory[dataptr].chr
        bytecode.arg.times do
          stdout_buffer << chr

          if chr == '\n'
            print stdout_buffer.to_s
            stdout_buffer.clear
          end
        end
      when .loop_set_to_zero?
        memory[dataptr] = 0
      when .loop_move_ptr?
        until memory[dataptr] == 0
          dataptr += bytecode.arg
        end
      when .loop_move_data?
        if memory[dataptr] > 0
          destptr = dataptr + bytecode.arg
          memory[destptr] &+= memory[dataptr]
          memory[dataptr] = 0
        end
      when .jump_if_data_zero?
        pc = bytecode.arg if memory[dataptr] == 0
      when .jump_if_data_not_zero?
        pc = bytecode.arg if memory[dataptr] != 0
      else
        raise "Invalid bytecode encountered on pc=#{pc}"
      end

      pc += 1
    end

    print stdout_buffer.to_s if !stdout_buffer.empty?
  end
end
