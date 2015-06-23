require "assert_performance/version"
require "benchmark"
require "parse-ruby-client"
require 'rubygems'
require "active_record"

##
# Benchmarks code and database calls and optionally submits results to a Parse database
#
# Modified from example in "Ruby Performance Optimization: Why Ruby Is Slow and How To Fix It"
# written by Alexander Dymo
#
#
module AssertPerformance

  class PerformanceTestTransactionError < StandardError
  end

  def self.benchmark_code(name, &block)
    operation_results = nil
    read, write = IO.pipe
    (0..30).each do |i|
      # Force GC to reclaim all memory used in previous run
      GC.start

      pid = fork do
        # GC extra memory that fork allocated
        GC.start
        # Disable GC if option set
        GC.disable if ENV["RUBY_DISABLE_GC"]

        # Store results in a between runs
        benchmark_results = File.open("benchmark_results_#{name}", "a")
        elapsed_time, memory_after, memory_before = nil
        begin
          ActiveRecord::Base.transaction do
            memory_before = `ps -o rss= -p #{Process.pid}`.to_i
            elapsed_time = Benchmark::realtime do
              operation_results = yield
            end
            memory_after = `ps -o rss= -p #{Process.pid}`.to_i
            raise PerformanceTestTransactionError
          end
        rescue PerformanceTestTransactionError
          # Rollback database
        end
        # Skip first run to exclude cold start measurements
        if i > 0
          # Store runtime
          benchmark_results.puts elapsed_time.round(6)
        end
        benchmark_results.close
        GC.enable if ENV["RUBY_DISABLE_GC"]

        read.close
        results = {results: operation_results , memory: (memory_after - memory_before)}
        Marshal.dump(results,write)
      end
      Process::waitpid pid
    end
    measurements = File.readlines("benchmark_results_#{name}").map do |value|
      value.to_f
    end
    File.delete("benchmark_results_#{name}")

    average = average(measurements).round(3)
    stddev = standard_deviation(measurements).round(3)

    # If parse object is set store results in parse database for further analysis
    id = nil
    if @parse
      parse_benchmark = Parse::Object.new("CodeBenchmark")
      parse_benchmark['time'] = Time.new
      parse_benchmark['name'] = name
      parse_benchmark['average'] = average
      parse_benchmark['standard_deviation'] = stddev
      parse_msg = parse_benchmark.save
      puts "Saving data to Parse: #{parse_msg}"
      id = parse_benchmark["objectId"]
    end
    # Return benchmark and operation results so they can be validated
    write.close
    process_results = read.read
    processed_results = Marshal.load(process_results)
    return {
      results: processed_results[:results],
      benchmark: {
        name: name,
        average: average,
        standard_deviation: stddev,
        memory: processed_results[:memory],
        id: id
      }
    }
  end

  def self.benchmark_database(name)
    result = []
    ActiveSupport::Notifications.subscribe "sql.active_record" do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      query_name = event.payload[:sql]
      next if ['SCHEMA'].include?(query_name)
      result << query_name
    end
    yield
    ActiveSupport::Notifications.unsubscribe("sql.active_record")
    id = nil
    if @parse
      parse_benchmark = Parse::Object.new("DatabaseBenchmark")
      parse_benchmark['name'] = name
      parse_benchmark['queries'] = result
      parse_msg = parse_benchmark.save
      puts "Saving data to Parse: #{parse_msg}"
      id = parse_benchmark["objectId"]
    end
    # Put results into hash under benchmark to match benchmark_code structure
    { benchmark: {name: name, queries: result, id: id} }
  end

  def self.standard_deviation(measurements)
    Math.sqrt(measurements.inject(0){|sum, x| sum + (x - average(measurements)) ** 2}.to_f / (measurements.size - 1))
  end

  def self.average(measurements)
    measurements.inject(0) { |sum, x| sum + x }.to_f / measurements.size
  end

  def self.setup_parse(parse_details)
    Parse.init(parse_details)
    @parse = true
    puts "Setting up parse"
  end
end
