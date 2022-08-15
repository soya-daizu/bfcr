struct Bytecode
  getter type : Type
  property arg : Int32

  def initialize(@type, @arg)
  end

  enum Type
    Invalid
    IncPtr
    DecPtr
    IncData
    DecData
    ReadStdin
    WriteStdout
    JumpIfDataZero
    JumpIfDataNotZero
    LoopSetToZero
    LoopMovePtr
    LoopMoveData

    def self.new(char : Char)
      case char
      when '>'
        IncPtr
      when '<'
        DecPtr
      when '+'
        IncData
      when '-'
        DecData
      when ','
        ReadStdin
      when '.'
        WriteStdout
      when '['
        JumpIfDataZero
      when ']'
        JumpIfDataNotZero
      else
        Invalid
      end
    end
  end
end
