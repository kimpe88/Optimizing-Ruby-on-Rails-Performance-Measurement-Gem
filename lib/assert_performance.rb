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
  # If Parse information is supplied setup Parse
  if ENV["application_key"] && ENV["api_key"]
    @parse = Parse.init(application_key: ENV["application_key"], api_key: ENV["api_key"], quiet: false)
  end

  def self.benchmark_code(name, &block)

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
        elapsed_time = nil
        begin
          ActiveRecord::Base.transaction do
            elapsed_time = Benchmark::realtime do
              yield
            end
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

        # Do we need hack here???

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
    if @parse
      res = Parse::Object.new("CodeBenchmark")
      res['time'] = Time.new
      res['name'] = name
      res['average'] = average
      res['standard_deviation'] = stddev
      parse_msg = res.save
      puts "Saving data to Parse: #{parse_msg}"
    end
    {name: name, average: average, standard_deviation: stddev}
  end

  def self.benchmark_database
    #TODO
  end

  def self.standard_deviation(measurements)
    Math.sqrt(measurements.inject(0){|sum, x| sum + (x - average(measurements)) ** 2}.to_f / (measurements.size - 1))
  end

  def self.average(measurements)
    measurements.inject(0) { |sum, x| sum + x }.to_f / measurements.size
  end
end
