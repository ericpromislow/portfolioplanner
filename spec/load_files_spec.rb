require 'rspec'
require 'date'
require 'common'
require 'parsers/rbc'
require 'parsers/td'
require 'yaml'

def process_path(analyzer, entries, path)
  entry = analyzer.parse(path)
  entries << entry
  # File.open(path.sub('.csv', '.yml'), 'w') do |fd|
  #   fd.puts(deep_stringify_symbols(entry).to_yaml)
  # end
end

describe "Load Files" do
  before do
    @spec_dir = File.dirname(__FILE__)
    @base_dir = File.absolute_path(File.dirname(@spec_dir))
    $:.push(File.join(@base_dir, "lib"))
    @input_dir = File.join(@base_dir, "test/fixtures")
  end
  
  it 'should load the rbc csv files' do
    dateObj = Date.parse('2020-08-15')
    glob = dateObj.strftime(Parsers::RBC::FileNameGlobFormat)
    rbc_paths = Dir.glob(File.join(@input_dir, glob))
    expect(rbc_paths.size).to eq(4)

    analyzer = Parsers::RBC::Analyzer.new
    entries = []
    rbc_paths.sort.each do |path|
      process_path(analyzer, entries, path)
    end
    expect(entries.size).to eq(4)
    expect(entries[0]).to include(
      accountName:'RSP',
      :accountNum=>"RBC01",
      :usrate=>1.3259,
      :cash=>{CAD:"68.45", USD:"42.10"},
      :stated_totals=>{CAD:"3600.00", USD:"2600.00"},
      :stated_investments=>{CAD:"3531.55", USD:"2557.90"},
    )
    expect(entries[0][:holdings].size).to eq(5)

    expect(entries[1]).to include(
      accountName:'LIRA',
      :accountNum=>"RBC02",
      :usrate=>1.3259,
      :cash=>{CAD:"49.61"},
      :stated_totals=>{CAD:"1100.00"},
      :stated_investments=>{CAD:"1050.39"},
    )
    expect(entries[1][:holdings].size).to eq(2)

    expect(entries[2]).to include(
      accountName:'Margin',
      :accountNum=>"RBC03",
      :usrate=>1.3259,
      :cash=>{USD:"91.70"},
      :stated_totals=>{USD:"4200.00"},
      :stated_investments=>{USD:"4108.30"},
    )
    expect(entries[2][:holdings].size).to eq(3)

    expect(entries[3]).to include(
      accountName:'TFSA',
      :accountNum=>"RBC04",
      :usrate=>1.3259,
      :cash=>{CAD:"191.98"},
      :stated_totals=>{CAD:"1600.00"},
      :stated_investments=>{CAD:"1408.02"},
    )
    expect(entries[3][:holdings].size).to eq(2)
  end

  it 'should load the td csv files' do
    dateObj = Date.parse('2020-08-15')
    glob = dateObj.strftime(Parsers::TD::FileNameGlobFormat)
    paths = Dir.glob(File.join(@input_dir, glob))
    expect(paths.size).to eq(1)

    analyzer = Parsers::TD::Analyzer.new
    entries = []
    paths.each do |path|
      process_path(analyzer, entries, path)
    end
    expect(entries.size).to eq(1)
    expect(entries[0]).to include(
      accountName:'Direct Investing',
      :accountNum=>"TD01",
      :usrate=>0,
      :cash=>{CAD:"96.00"},
      :stated_totals=>{CAD:"5000.00"},
      :stated_investments=>{CAD:"4904.00"},
    )
    expect(entries[0][:holdings].size).to eq(2)
  end
end
