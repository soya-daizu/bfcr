module Translator
  extend self

  def translate_program(instructions : Array(Char), optimize : Bool) : Array(Command)
    commands = [] of Command
    pc = 0
    program_size = instructions.size
    open_bracket_stack = [] of Int32

    while pc < program_size
      instruction = instructions[pc]

      if instruction == '['
        open_bracket_stack.push(commands.size)
        commands.push(Command.new(Command::Type::JumpIfDataZero))
        pc += 1
      elsif instruction == ']'
        raise "unmatched closing ']' at pc=#{pc}" if open_bracket_stack.empty?
        open_bracket_offset = open_bracket_stack.pop

        if optimize
          optimized_loop = optimize_loop(commands, open_bracket_offset)
        end

        if optimized_loop && !optimized_loop.empty?
          commands[open_bracket_offset..] = optimized_loop
        else
          open_bracket_command = commands[open_bracket_offset]
          open_bracket_command.arg = commands.size
          commands[open_bracket_offset] = open_bracket_command
          commands.push(Command.new(Command::Type::JumpIfDataNotZero, open_bracket_offset))
        end
        pc += 1
      else
        num_repeats = 1
        if optimize
          i = pc + 1
          while instructions[i]? == instruction
            i += 1
          end
          num_repeats = i - pc
        end

        type = Command::Type.new(instruction)
        negative = instruction == '-' || instruction == '<'
        commands.push(Command.new(type, negative ? -num_repeats : num_repeats))
        pc += num_repeats
      end
    end

    commands
  end

  private def optimize_loop(commands : Array(Command), loop_start : Int32)
    new_commands = [] of Command
    loop_length = commands.size - loop_start - 1

    if loop_length == 1
      loop_single(commands[loop_start + 1, loop_length], new_commands)
    elsif loop_length == 4
      loop_move_data(commands[loop_start + 1, loop_length], new_commands)
    end

    new_commands
  end

  private def loop_single(commands : Array(Command), new_commands : Array(Command))
    # Detect patterns: [+] [-] [>] [<]
    repeated_command = commands.first

    case repeated_command.type
    when .inc_data?
      new_commands.push(Command.new(Command::Type::Clear))
    when .inc_ptr?
      new_commands.push(Command.new(Command::Type::Scan, repeated_command.arg))
    end
  end

  private def loop_move_data(commands : Array(Command), new_commands : Array(Command))
    # Detect patterns: [->+<] [-<+>]
    if commands[0].type == Command::Type::IncData &&
       commands[1].type == Command::Type::IncPtr &&
       commands[2].type == Command::Type::IncData &&
       commands[3].type == Command::Type::IncPtr &&
       commands[0].arg == -1 && commands[2].arg > 0 &&
       commands[1].arg == -commands[3].arg
      new_commands.push(Command.new(Command::Type::Multiply, commands[1].arg, commands[2].arg))
    end
  end
end
