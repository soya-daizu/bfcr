require "option_parser"
require "./compiler/compiler"
require "./interpreter/interpreter"

mode = nil
filename = nil
optimize = true
OptionParser.parse do |parser|
  parser.on("run", "Run in interpreter mode") do
    mode = 0
  end
  parser.on("jit", "Run in JIT mode") do
    mode = 1
  end
  parser.on("build", "Build executable file") do
    mode = 2
  end

  parser.on("--no-opt", "Run/build without any optimization") do
    optimize = false
  end

  parser.unknown_args do |args, _|
    filename = args.first
  end
end

unless mode
  puts "Error: Mode not specified"
  exit 1
end
unless filename
  puts "Error: Filename not specified"
  exit 1
end
text = File.read(filename.not_nil!)

case mode
when 0
  interpreter = Interpreter.new(text, optimize)
  interpreter.run
when 1
  compiler = Compiler.new(text)
  compiler.optimize if optimize
  compiler.run_jit
when 2
  compiler = Compiler.new(text)
  compiler.optimize if optimize
  compiler.build_executable
end
