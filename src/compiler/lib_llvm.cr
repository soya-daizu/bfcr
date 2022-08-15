require "llvm"

# Extend LLVM bindings built in to Crystal
lib LibLLVM
  type OrcThreadSafeContextRef = Void*
  type OrcThreadSafeModuleRef = Void*

  type OrcLLJITBuilderRef = Void*
  type OrcLLJITRef = Void*

  type OrcSymbolStringPoolEntryRef = Void*
  alias OrcSymbolPredicate = Proc(Void*, OrcSymbolStringPoolEntryRef, Int32)

  type OrcJITDylibRef = Void*
  type OrcDefinitionGeneratorRef = Void*

  alias OrcExecutorAddress = Void*

  fun get_error_message = LLVMGetErrorMessage(err : ErrorRef) : UInt8*

  fun build_array_alloca = LLVMBuildArrayAlloca(builder : BuilderRef, type : TypeRef, val : ValueRef, name : UInt8*) : ValueRef
  fun build_mem_set = LLVMBuildMemSet(builder : BuilderRef, ptr : ValueRef, val : ValueRef, len : ValueRef, align : UInt)

  fun orc_create_new_thread_safe_context = LLVMOrcCreateNewThreadSafeContext : OrcThreadSafeContextRef
  fun orc_thread_safe_context_get_context = LLVMOrcThreadSafeContextGetContext(ts_ctx : OrcThreadSafeContextRef) : ContextRef
  fun orc_create_new_thread_safe_module = LLVMOrcCreateNewThreadSafeModule(mod : ModuleRef, ts_ctx : OrcThreadSafeContextRef) : OrcThreadSafeModuleRef

  fun orc_create_lljit_builder = LLVMOrcCreateLLJITBuilder : OrcLLJITBuilderRef
  fun orc_create_lljit = LLVMOrcCreateLLJIT(result : OrcLLJITRef*, builder : OrcLLJITBuilderRef) : ErrorRef

  fun orc_lljit_get_global_prefix = LLVMOrcLLJITGetGlobalPrefix(jit : OrcLLJITRef) : UInt8
  fun orc_lljit_mangle_and_intern = LLVMOrcLLJITMangleAndIntern(jit : OrcLLJITRef, unmangled_name : UInt8*) : OrcSymbolStringPoolEntryRef

  fun orc_lljit_get_main_jit_dylib = LLVMOrcLLJITGetMainJITDylib(jit : OrcLLJITRef) : OrcJITDylibRef
  fun orc_create_dynamic_library_search_generator_for_process = LLVMOrcCreateDynamicLibrarySearchGeneratorForProcess(result : OrcDefinitionGeneratorRef*, global_prefix : UInt8, filter : OrcSymbolPredicate, filter_ctx : Void*) : ErrorRef
  fun orc_jit_dylib_add_generator = LLVMOrcJITDylibAddGenerator(jd : OrcJITDylibRef, dg : OrcDefinitionGeneratorRef)

  fun orc_lljit_add_llvm_ir_module = LLVMOrcLLJITAddLLVMIRModule(jit : OrcLLJITRef, jd : OrcJITDylibRef, tsm : OrcThreadSafeModuleRef) : ErrorRef
  fun orc_lljit_lookup = LLVMOrcLLJITLookup(jit : OrcLLJITRef, result : OrcExecutorAddress*, name : UInt8*) : ErrorRef
end
