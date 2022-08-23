struct Command
  getter type : Type
  property arg : Int32

  def initialize(@type, @arg = 0)
  end

  enum Type
    Invalid
    IncPtr
    IncData
    ReadStdin
    WriteStdout
    JumpIfDataZero
    JumpIfDataNotZero
    Clear
    Scan
    Copy

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
