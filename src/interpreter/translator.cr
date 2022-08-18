module Translator
  extend self

  def translate_program(instructions : Array(Char), optimize : Bool) : Array(Bytecode)
    bytecodes = [] of Bytecode
    pc = 0
    program_size = instructions.size
    open_bracket_stack = [] of Int32

    while pc < program_size
      instruction = instructions[pc]

      if instruction == '['
        open_bracket_stack.push(bytecodes.size)
        bytecodes.push(Bytecode.new(Bytecode::Type::JumpIfDataZero, 0))
        pc += 1
      elsif instruction == ']'
        raise "unmarched closing ']' at pc=#{pc}" if open_bracket_stack.empty?
        open_bracket_offset = open_bracket_stack.pop

        if optimize
          optimized_loop = optimize_loop(bytecodes, open_bracket_offset)
        end

        if optimized_loop && !optimized_loop.empty?
          bytecodes[open_bracket_offset..] = optimized_loop
        else
          open_bracket_bytecode = bytecodes[open_bracket_offset]
          open_bracket_bytecode.arg = bytecodes.size
          bytecodes[open_bracket_offset] = open_bracket_bytecode
          bytecodes.push(Bytecode.new(Bytecode::Type::JumpIfDataNotZero, open_bracket_offset))
        end
        pc += 1
      else
        num_repeats = 1
        if optimize
          i = pc + 1
          while i < program_size && instructions[i] == instruction
            i += 1
          end
          num_repeats = i - pc
        end

        type = Bytecode::Type.new(instruction)
        negative = instruction == '-' || instruction == '<'
        bytecodes.push(Bytecode.new(type, negative ? -num_repeats : num_repeats))
        pc += num_repeats
      end
    end

    bytecodes
  end

  private def optimize_loop(bytecodes : Array(Bytecode), loop_start : Int32)
    new_bytecodes = [] of Bytecode
    loop_length = bytecodes.size - loop_start - 1

    if loop_length == 1
      loop_single(bytecodes[loop_start + 1, loop_length], new_bytecodes)
    elsif loop_length == 4
      loop_move_data(bytecodes[loop_start + 1, loop_length], new_bytecodes)
    else
    end

    new_bytecodes
  end

  private def loop_single(bytecodes : Array(Bytecode), new_bytecodes : Array(Bytecode))
    # Detect patterns: [+] [-] [>] [<]
    repeated_bytecode = bytecodes.first

    case repeated_bytecode.type
    when .inc_data?
      new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopSetToZero, 0))
    when .inc_ptr?
      new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopMovePtr, repeated_bytecode.arg))
    end
  end

  private def loop_move_data(bytecodes : Array(Bytecode), new_bytecodes : Array(Bytecode))
    # Detect patterns: [->+<] [-<+>]
    if bytecodes[0].type == Bytecode::Type::IncData &&
       bytecodes[1].type == Bytecode::Type::IncPtr &&
       bytecodes[2].type == Bytecode::Type::IncData &&
       bytecodes[3].type == Bytecode::Type::IncPtr &&
       bytecodes[0].arg == -bytecodes[2].arg &&
       bytecodes[1].arg == -bytecodes[3].arg
      new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopMoveData, bytecodes[1].arg))
    end
  end
end
