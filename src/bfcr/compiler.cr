require "llvm"
require "./ir_builder"
require "./translator"

class Compiler
  def initialize(text : String, optimize : Bool)
    triple = LLVM.default_target_triple
    architecture = triple.split('-').first
    case architecture
    when "i486", "i586", "i686", "i386", "x86_64", "amd64"
      LLVM.init_x86
    when "arm64", "aarch64"
      LLVM.init_aarch64
    when .starts_with?("arm")
      LLVM.init_arm
    else
    end

    @ts_ctx = LibLLVM.orc_create_new_thread_safe_context
    @ctx = LLVM::Context.new(LibLLVM.orc_thread_safe_context_get_context(@ts_ctx))
    @mod = @ctx.new_module("bfcr")

    instructions = text.gsub(/[^\[\]<>+\-,\.]/, "").chars
    commands = Translator.translate_program(instructions, optimize)
    builder = IRBuilder.new(@ctx, @mod, commands)
    builder.build
  end

  def optimize
    puts "Optimizing..."
    pm_builder = LLVM::PassManagerBuilder.new
    pm_builder.opt_level = 3
    pm_builder.size_level = 0

    function_pm = @mod.new_function_pass_manager
    module_pm = LLVM::ModulePassManager.new
    pm_builder.populate(function_pm)
    pm_builder.populate(module_pm)

    function_pm.run(@mod)
    module_pm.run(@mod)
  end

  def run_jit
    builder = LibLLVM.orc_create_lljit_builder
    jit = uninitialized LibLLVM::OrcLLJITRef
    err = LibLLVM.orc_create_lljit(pointerof(jit), builder)
    raise String.new(LibLLVM.get_error_message(err)) if err

    allow_list = Pointer(LibLLVM::OrcSymbolStringPoolEntryRef).malloc(4)
    allow_list[0] = LibLLVM.orc_lljit_mangle_and_intern(jit, "getchar")
    allow_list[1] = LibLLVM.orc_lljit_mangle_and_intern(jit, "putchar")
    allow_list[2] = LibLLVM.orc_lljit_mangle_and_intern(jit, "__bzero")
    allow_list[3] = LibLLVM.orc_lljit_mangle_and_intern(jit, "memset")

    generator = uninitialized LibLLVM::OrcDefinitionGeneratorRef
    err = LibLLVM.orc_create_dynamic_library_search_generator_for_process(
      pointerof(generator),
      LibLLVM.orc_lljit_get_global_prefix(jit),
      ->(ctx, sym) {
        list = ctx.as(LibLLVM::OrcSymbolStringPoolEntryRef*).to_slice(4)
        list.each do |p|
          return 1 if sym == p
        end
        0
      },
      allow_list
    )
    raise String.new(LibLLVM.get_error_message(err)) if err

    jd = LibLLVM.orc_lljit_get_main_jit_dylib(jit)
    LibLLVM.orc_jit_dylib_add_generator(jd, generator)

    tsm = LibLLVM.orc_create_new_thread_safe_module(@mod, @ts_ctx)
    err = LibLLVM.orc_lljit_add_llvm_ir_module(jit, jd, tsm)
    raise String.new(LibLLVM.get_error_message(err)) if err

    main_ptr = uninitialized LibLLVM::OrcExecutorAddress
    err = LibLLVM.orc_lljit_lookup(jit, pointerof(main_ptr), "main")
    raise String.new(LibLLVM.get_error_message(err)) if err

    main = Proc(Void).new(main_ptr, Pointer(Void).null)
    main.call
  end

  def build_executable(output_name : String)
    puts "Building..."
    triple = LLVM.default_target_triple
    target = LLVM::Target.from_triple(triple)
    target_machine = target.create_target_machine(triple, opt_level: LLVM::CodeGenOptLevel::Aggressive)
    target_machine.emit_obj_to_file(@mod, "#{output_name}.o")
    `gcc -o #{output_name} #{output_name}.o`
  end
end
