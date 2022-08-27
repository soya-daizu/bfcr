require "benchmark"
require "http/client"
require "ishi/png"

EXAMPLE_INTERPRETER_URL = "https://gist.githubusercontent.com/soya-daizu/16eed302d7d4d55181f5f5243ef08a50/raw/0d7effeffb64808b5f8717d3013ef65b8d746eec/patched_brainfuck.cr"
def build_example_interpreter
  puts "Downloading example interpreter..."
  HTTP::Client.get(EXAMPLE_INTERPRETER_URL) do |response|
    File.open("patched_brainfuck.cr", "w") do |file|
      file.print(response.body_io.gets_to_end)
    end
  end
  puts "Building example interpreter..."
  `crystal build patched_brainfuck.cr --release`
  raise "Building example interpreter failed" unless $?.success?
end

def perform(command : String)
  puts "COMMAND: #{command}"

  avg = Time::Span.zero
  5.times do |i|
    time = Benchmark.realtime { `#{command}` }
    puts "iter. #{i + 1} --- #{time}"
    avg += time
  end
  avg /= 5
  puts "avg.    --- #{avg}"

  avg
end

def plot_graph(program : String, results : Hash(String, Time::Span))
  File.open("media/#{program}.png", "w") do |file|
    Ishi.new(file) do
      x = (1..7).to_a
      y = results.values.map(&.to_f)
      xtics = results.keys.map_with_index { |m, i| {(i + 1).to_f, m} }.to_h

      plot(x, y, title: "Execution time (sec.)", style: :boxes, fs: 0.25)
        .boxwidth(0.5)
        .ylabel("Execution time (5 times avg.)")
        .xlabel("Mode")
        .xtics(xtics)
    end
  end
end

def plot_table(results : Hash(String, Time::Span))
  titles = [] of String
  values = [] of String

  results.each do |key_str, time|
    time_str = time.to_f.round(3).to_s
    length_diff = key_str.size - time_str.size

    if length_diff > 0
      time_str = time_str.ljust(time_str.size + length_diff)
    elsif length_diff < 0
      key_str = key_str.ljust(key_str.size - length_diff)
    end

    titles.push(key_str)
    values.push(time_str)
  end
  h_separators = titles.map(&.gsub(/./, '-'))

  String.build do |str|
    str << "| " << titles.join(" | ") << " |" << '\n'
    str << "| " << h_separators.join(" | ") << " |" << '\n'
    str << "| " << values.join(" | ") << " |" << '\n'
  end
end

bfcr_exists = File.exists?("bin/bfcr")
unless bfcr_exists
  puts "Bfcr not found. Now building..."
  `shards build --release`
  raise "Building bfcr failed" unless $?.success?
end

build_example_interpreter unless File.exists?("patched_brainfuck")

programs = Dir.glob("samples/*.bf")
programs.each do |program|
  program_name = program.match(/\w+\/(\w+).bf/).try(&.[1]) || "unknown"
  puts "PROGRAM: #{program_name}.bf"
  results = {} of String => Time::Span

  input = if program == "samples/factor.bf"
            %q(echo "179424691\n" | )
          else
            ""
          end

  results["brainfuck.cr"] = perform("#{input}./patched_brainfuck #{program}")

  results["run"] = perform("#{input}bin/bfcr run #{program}")

  results["run (no opt)"] = perform("#{input}bin/bfcr run #{program} --no-opt")

  results["jit"] = perform("#{input}bin/bfcr jit #{program}")

  results["jit (no opt)"] = perform("#{input}bin/bfcr jit #{program} --no-opt")

  puts "Building #{program} ..."
  `bin/bfcr build #{program}`
  raise "Building #{program} failed" unless $?.success?
  results["build"] = perform("#{input}./out")

  puts "Building #{program} --no-opt ..."
  `bin/bfcr build #{program} --no-opt`
  raise "Building #{program} --no-opt failed" unless $?.success?
  results["build (no opt)"] = perform("#{input}./out")

  plot_graph(program_name, results)
  puts plot_table(results)
end
