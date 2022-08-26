require "benchmark"
require "ishi/png"

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

def plot_chart(program : String, results : Hash(String, Time::Span))
  File.open("media/#{program}.png", "w") do |file|
    Ishi.new(file) do
      x = (1..6).to_a
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
  String.build do |str|
    str << '|' << results.keys.join('|') << '|' << '\n'

    str << '|'
    results.size.times do
      str << "---" << '|'
    end
    str << '\n'

    str << '|' << results.values.map(&.to_f.round(3)).join('|') << '|' << '\n'
  end
end

bfcr_exists = File.exists?("bin/bfcr")
unless bfcr_exists
  puts "Bfcr not found. Now building..."
  `shards build --release`
  raise "Building bfcr failed" unless $?.success?
end

programs = Dir.glob("samples/*.bf")
programs.each do |program|
  puts "PROGRAM: #{program}"
  results = {} of String => Time::Span

  input = if program == "samples/factor.bf"
            %q(echo "179424691\n" | )
          else
            ""
          end

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

  plot_chart(program.match(/\w+\/(\w+).bf/).try(&.[1]) || "unknown", results)
  puts plot_table(results)
end
