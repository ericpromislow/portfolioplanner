require 'rspec'
require 'date'
require 'yaml'

require 'analyze'
require 'common'
require 'parsers/rbc'
require 'parsers/td'

describe 'Analyze' do

  before do
    @spec_dir = File.dirname(__FILE__)
    @base_dir = File.absolute_path(File.dirname(@spec_dir))
    $:.push(File.join(@base_dir, "lib"))
    @input_dir = File.join(@base_dir, "test/fixtures")
  end

  it 'should load the rbc csv files' do
    dateObj = Date.parse('2020-08-15')
    glob = dateObj.strftime(Parsers::RBC::FileNameGlobFormat).sub(/\.csv\z/, '.yml')
    rbc_paths = Dir.glob(File.join(@input_dir, glob))
    expect(rbc_paths.size).to eq(4)
    glob = dateObj.strftime(Parsers::TD::FileNameGlobFormat).sub(/\.csv\z/, '.yml')
    td_paths = Dir.glob(File.join(@input_dir, glob))
    expect(td_paths.size).to eq(1)

    sources = [
      {
        sourceName: :RBC,
        entries: rbc_paths.map{|path| deep_symbolize_keys(YAML.load_file(path))}
      },
      {
        sourceName: :TD,
        entries: td_paths.map{|path| deep_symbolize_keys(YAML.load_file(path))}
      },
    ]

    analyzer = Analyze::Analyzer.new(File.join(@input_dir, "categories.yml"))
    analyzer.process(sources)
    summary = analyzer.get_summary()
    expect(summary[:full_total]).to be_within(0.001).of(summary[:total_check_by_category])

    totals_by_category = summary[:totals_by_category]
    %i/CAD USD/.each do |currency|
      expect(totals_by_category[:investments][currency]).
        to be_within(0.001).of(totals_by_category[:stated_investments][currency])
      expect(totals_by_category[:totals][currency]).
        to be_within(0.001).of(totals_by_category[:stated_totals][currency])
      expect(totals_by_category[:totals][currency]).
        to be_within(0.001).of(totals_by_category[:cash][currency] +
                               totals_by_category[:investments][currency])
    end

    adjustments = summary[:adjustments_by_category]
    expected_adjustments = {CdnEq: -5479.67, USEq: -5699.71, IntlEq: -17.12, Resources: 157.99,
    Bonds: 5138.07, ShortTerm: 5900.42}
    expected_adjustments.each do |category, expected_adjustment|
      adjustment = adjustments[category]
      expect(expected_adjustment).to be_within(0.01).of(adjustment[:delta])
    end
  end

  it 'can print a summary' do
    dateObj = Date.parse('2020-08-15')
    glob = dateObj.strftime(Parsers::RBC::FileNameGlobFormat).sub(/\.csv\z/, '.yml')
    rbc_paths = Dir.glob(File.join(@input_dir, glob))
    expect(rbc_paths.size).to eq(4)
    glob = dateObj.strftime(Parsers::TD::FileNameGlobFormat).sub(/\.csv\z/, '.yml')
    td_paths = Dir.glob(File.join(@input_dir, glob))
    expect(td_paths.size).to eq(1)

    sources = [
      {
        sourceName: :RBC,
        entries: rbc_paths.map{|path| deep_symbolize_keys(YAML.load_file(path))}
      },
      {
        sourceName: :TD,
        entries: td_paths.map{|path| deep_symbolize_keys(YAML.load_file(path))}
      },
    ]

    analyzer = Analyze::Analyzer.new(File.join(@input_dir, "categories.yml"))
    analyzer.process(sources)
    analyzer.print_summary

  end
end
