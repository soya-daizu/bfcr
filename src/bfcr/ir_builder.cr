require "./lib_llvm"
require "./loop_blocks"

class IRBuilder
  def initialize(@ctx : LLVM::Context, @mod : LLVM::Module, @commands : Array(Command))
  end

  def build
    funcs = @mod.functions

    putchar_func = @mod.functions.add("putchar", [@ctx.int32], @ctx.int32)
    putchar_func.linkage = LLVM::Linkage::External
    getchar_func = @mod.functions.add("getchar", [] of LLVM::Type, @ctx.int32)
    getchar_func.linkage = LLVM::Linkage::External

    main_func = @mod.functions.add("main", [] of LLVM::Type, @ctx.int32)
    main_func.linkage = LLVM::Linkage::External
    block = main_func.basic_blocks.append("entry")
    builder = @ctx.new_builder
    builder.position_at_end(block)

    memory = LibLLVM.build_array_alloca(builder, @ctx.int8, @ctx.int32.const_int(30000), "memory")
    LibLLVM.build_mem_set(builder, memory, @ctx.int8.const_int(0), @ctx.int64.const_int(30000), 1)
    dataptr_addr = builder.alloca(@ctx.int32, "dataptr_addr")
    builder.store(@ctx.int32.const_int(0), dataptr_addr)

    pc = 0
    loop_stack = [] of LoopBlocks
    if_count = 0
    while pc < @commands.size
      command = @commands[pc]
      case command.type
      when .inc_ptr?
        emit_move_ptr(command.arg)
      when .inc_data?
        emit_mod_data(command.arg)
      when .read_stdin?
        command.arg.times do
          emit_getchar
        end
      when .write_stdout?
        command.arg.times do
          emit_putchar
        end
      when .clear?
        emit_clear
      when .scan?
        emit_loop_start
        emit_move_ptr(command.arg)
        emit_loop_end
      when .multiply?
        emit_if_not_zero
        emit_multiply
        emit_if_end
        if_count += 1
      when .jump_if_data_zero?
        emit_loop_start
      when .jump_if_data_not_zero?
        emit_loop_end
      else
        raise "bad char '#{command}' at pc=#{pc}"
      end

      pc += 1
    end

    builder.ret(@ctx.int32.const_int(0))
  end

  private macro emit_move_ptr(val)
    dataptr = builder.load(dataptr_addr, "dataptr")
    inc_dataptr = builder.add(dataptr, @ctx.int32.const_int({{ val }}), "inc_dataptr")
    builder.store(inc_dataptr, dataptr_addr)
  end

  private macro emit_mod_data(val)
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    element = builder.load(element_addr, "element")
    inc_element = builder.add(element, @ctx.int8.const_int({{ val }}), "inc_element")
    builder.store(inc_element, element_addr)
  end

  private macro emit_getchar
    user_input = builder.call(getchar_func, [] of LLVM::Value, "user_input")
    user_input_i8 = builder.trunc(user_input, @ctx.int8, "user_input_i8")
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    builder.store(user_input_i8, element_addr)
  end

  private macro emit_putchar
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    element = builder.load(element_addr, "element")
    element_i32 = builder.zext(element, @ctx.int32, "element_i32")
    builder.call(putchar_func, [element_i32])
  end

  private macro emit_loop_start
    loop_blocks = LoopBlocks.new(main_func, loop_stack.size)
    builder.br(loop_blocks.cond_block)

    builder.position_at_end(loop_blocks.cond_block)
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    element = builder.load(element_addr, "element")
    cmp = builder.icmp(LLVM::IntPredicate::EQ, element, @ctx.int8.const_int(0), "compare_zero")
    builder.cond(cmp, loop_blocks.end_block, loop_blocks.body_block)

    builder.position_at_end(loop_blocks.body_block)
    loop_stack.push(loop_blocks)
  end

  private macro emit_loop_end
    loop_blocks = loop_stack.pop
    builder.br(loop_blocks.cond_block)
    builder.position_at_end(loop_blocks.end_block)
  end

  private macro emit_if_not_zero
    cond_block = main_func.basic_blocks.append("if_cond#{if_count}")
    body_block = main_func.basic_blocks.append("if_body#{if_count}")
    end_block = main_func.basic_blocks.append("if_end#{if_count}")
    builder.br(cond_block)

    builder.position_at_end(cond_block)
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    element = builder.load(element_addr, "element")
    cmp = builder.icmp(LLVM::IntPredicate::EQ, element, @ctx.int8.const_int(0), "compare_zero")
    builder.cond(cmp, end_block, body_block)

    builder.position_at_end(body_block)
  end

  private macro emit_if_end
    builder.br(end_block)
    builder.position_at_end(end_block)
  end

  private macro emit_clear
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    builder.store(@ctx.int8.const_int(0), element_addr)
  end

  private macro emit_multiply
    dataptr = builder.load(dataptr_addr, "dataptr")
    element_addr = builder.inbounds_gep(memory, dataptr, "element_addr")
    element = builder.load(element_addr, "element")

    dest_dataptr = builder.add(dataptr, @ctx.int32.const_int(command.arg), "dest_dataptr")
    dest_element_addr = builder.inbounds_gep(memory, dest_dataptr, "dest_element_addr")
    dest_element = builder.load(dest_element_addr, "dest_element")
    inc_dest_element = builder.add(dest_element, element, "inc_dest_element")
    if command.arg2 != 1
      inc_dest_element = builder.mul(inc_dest_element, @ctx.int32.const_int(command.arg2), "mul_dest_element")
    end
    builder.store(inc_dest_element, dest_element_addr)
    builder.store(@ctx.int8.const_int(0), element_addr)
  end
end
