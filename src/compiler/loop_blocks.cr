struct LoopBlocks
  getter cond_block : LLVM::BasicBlock
  getter body_block : LLVM::BasicBlock
  getter end_block : LLVM::BasicBlock

  def initialize(main_func : LLVM::Function, loop_id : Int32)
    @cond_block = main_func.basic_blocks.append("loop_start#{loop_id}")
    @body_block = main_func.basic_blocks.append("loop_body#{loop_id}")
    @end_block = main_func.basic_blocks.append("loop_end#{loop_id}")
  end
end
