require 'spec_helper'
require 'sqlite3'

describe AssertPerformance do
  before :each do
    ActiveRecord::Base.establish_connection(
        adapter:  'sqlite3',
        database: 'spec_db/test_db.sqlite'
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
    end
    expect(results[:name]).to eq "Test"
    expect(results[:average].round(2)).to eq 0.10
    expect(results[:standard_deviation].round(2)).to eq 0.00
  end

  it 'it successfully posts information to parse' do
    pending
  end
end
