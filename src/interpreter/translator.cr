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

        if !optimized_loop || optimized_loop.empty?
          open_bracket_bytecode = bytecodes[open_bracket_offset]
          open_bracket_bytecode.arg = bytecodes.size
          bytecodes[open_bracket_offset] = open_bracket_bytecode
          bytecodes.push(Bytecode.new(Bytecode::Type::JumpIfDataNotZero, open_bracket_offset))
        else
          bytecodes[open_bracket_offset..] = optimized_loop
        end
        pc += 1
      else
        if optimize
          i = pc + 1
          while i < program_size && instructions[i] == instruction
            i += 1
          end
          num_repeats = i - pc
        else
          num_repeats = 1
        end

        type = Bytecode::Type.new(instruction)
        bytecodes.push(Bytecode.new(type, num_repeats))
        pc += num_repeats
      end
    end

    bytecodes
  end

  private def optimize_loop(bytecodes : Array(Bytecode), loop_start : Int32)
    new_bytecodes = [] of Bytecode

    if bytecodes.size - loop_start == 2
      repeated_bytecode = bytecodes[loop_start + 1]

      case repeated_bytecode.type
      when .inc_data?, .dec_data?
        new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopSetToZero, 0))
      when .inc_ptr?
        new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopMovePtr, repeated_bytecode.arg))
      when .dec_ptr?
        new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopMovePtr, -repeated_bytecode.arg))
      end
    elsif bytecodes.size - loop_start == 5
      if bytecodes[loop_start + 1].arg == 1 && bytecodes[loop_start + 3].arg == 1 &&
         bytecodes[loop_start + 2].arg == bytecodes[loop_start + 4].arg
        case {bytecodes[loop_start + 1].type,
              bytecodes[loop_start + 2].type,
              bytecodes[loop_start + 3].type,
              bytecodes[loop_start + 4].type}
        when {Bytecode::Type::DecData,
              Bytecode::Type::IncPtr,
              Bytecode::Type::IncData,
              Bytecode::Type::DecPtr}
          new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopMoveData, bytecodes[loop_start + 2].arg))
        when {Bytecode::Type::DecData,
              Bytecode::Type::DecPtr,
              Bytecode::Type::IncData,
              Bytecode::Type::IncPtr}
          new_bytecodes.push(Bytecode.new(Bytecode::Type::LoopMoveData, -bytecodes[loop_start + 2].arg))
        end
      end
    end

    new_bytecodes
  end
end
