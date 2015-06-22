require 'spec_helper'
require 'sqlite3'
require 'yaml'
require 'pry'

describe AssertPerformance do
  before :each do
    ActiveRecord::Base.establish_connection(
        adapter:  'sqlite3',
        database: 'spec_extra/test_db.sqlite'
    )
  end

  it 'has a version number' do
    expect(AssertPerformance::VERSION).not_to be nil
  end

  it 'calculates average correctly' do
    expect(AssertPerformance.average([1,2,3,4,5])).to be 3.0
  end

  it 'calculates standard deviation correctly' do
    expect(AssertPerformance.standard_deviation([1,2,3,4,5]).round(5)).to be 1.58114
  end

  it 'measures execution time correctly' do
    results = AssertPerformance.benchmark_code("Test") do
      sleep 0.1
      200
    end
    expect(results[:benchmark][:name]).to eq "Test"
    expect(results[:benchmark][:average].round(2)).to eq 0.10
    expect(results[:benchmark][:standard_deviation].round(2)).to eq 0.00
    expect(results[:results]).to eq 200
  end

  it 'benchmarks database queries correctly' do
    result = bench_db
    expect(result[:benchmark][:queries].length).to be 1
  end

  describe "parse database" do
    before :all do
      configuration = YAML.load(File.read('spec_extra/secret.yml'))
      AssertPerformance.setup_parse(configuration[:parse])
    end
    it 'it successfully posts code bench information to parse' do
      results = AssertPerformance.benchmark_code("Test") do
        sleep 0.1
      end
      expect(results[:benchmark][:name]).to eq "Test"
      expect(results[:benchmark][:average].round(2)).to eq 0.10
      expect(results[:benchmark][:standard_deviation].round(2)).to eq 0.00
      expect(results[:benchmark][:id]).to_not be nil
      saved_benchmark = Parse::Query.new("CodeBenchmark").eq("objectId", results[:benchmark][:id]).get.first
      saved_benchmark.parse_delete
      # Double check so we don't leave any useless test data in Parse db
      expect(Parse::Query.new("CodeBenchmark").eq("objectId", results[:benchmark][:id]).get.length).to be 0
    end

    it 'successfully post database bench information to parse' do
      results = bench_db
      expect(results[:benchmark][:name]).to eq "Test"
      expect(results[:benchmark][:queries].length).to be 1
      expect(results[:benchmark][:id]).to_not be nil
      saved_benchmark = Parse::Query.new("DatabaseBenchmark").eq("objectId", results[:benchmark][:id]).get.first
      saved_benchmark.parse_delete
      # Double check so we don't leave any useless test data in Parse db
      expect(Parse::Query.new("DatabaseBenchmark").eq("objectId", results[:benchmark][:id]).get.length).to be 0
    end
  end
  private
  def bench_db
    result = {}
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute <<-SQL
      create table test(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
      );
      SQL
      (1..100).each do |i|
        ActiveRecord::Base.connection.execute <<-SQL
        INSERT INTO test (name) VALUES("name#{i}");
        SQL
      end

      result = AssertPerformance.benchmark_database("Test") do
        ActiveRecord::Base.connection.execute "SELECT * FROM test WHERE id > 50"
      end
      raise ActiveRecord::Rollback
    end
    result
  end
end
