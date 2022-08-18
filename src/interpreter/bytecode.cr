struct Bytecode
  getter type : Type
  property arg : Int32

  def initialize(@type, @arg)
  end

  enum Type
    Invalid
    IncPtr
    IncData
    ReadStdin
    WriteStdout
    JumpIfDataZero
    JumpIfDataNotZero
    LoopSetToZero
    LoopMovePtr
    LoopMoveData

    def self.new(char : Char)
      case char
      when '>', '<'
        IncPtr
      when '+', '-'
        IncData
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
