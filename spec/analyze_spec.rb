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

  describe 'loading the data' do
    before do
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
          entries: rbc_paths.map {|path| deep_symbolize_keys(YAML.load_file(path))}
        },
        {
          sourceName: :TD,
          entries: td_paths.map {|path| deep_symbolize_keys(YAML.load_file(path))}
        },
      ]

      @analyzer = Analyze::Analyzer.new(File.join(@input_dir, "categories.yml"))
      @analyzer.process(sources)
    end

    it 'should load the rbc csv files' do
      summary = @analyzer.get_summary()
      expect(summary[:full_total]).to be_within(0.001).of(summary[:total_check_by_category])

      totals_by_category = summary[:totals_by_category]
      %i/CAD USD/.each do |currency|
        expect(totals_by_category[:investments][currency]).
          to be_within(0.001).of(totals_by_category[:stated_investments][currency])
        expect(totals_by_category[:totals][currency]).
          to be_within(0.001).of(totals_by_category[:stated_totals][currency]),
            "#{currency}: expected totals_by_category[:totals][currency]=#{totals_by_category[:totals][currency]} to be within 0.001 of totals_by_category[:stated_totals][currency]=#{totals_by_category[:stated_totals][currency]}"
        expect(totals_by_category[:totals][currency]).
          to be_within(0.001).of(totals_by_category[:cash][currency] +
            totals_by_category[:investments][currency])
      end

      adjustments = summary[:adjustments_by_category]
      expected_adjustments = {:CdnEq=>-5458.51,
        :USEq=>-5685.60,
        :IntlEq=>-5.83,
        :Resources=>167.87,
        :Bonds=>5171.93,
        :ShortTerm=>5884.66,
        :UNCATEGORIZED=>-74.52}


      expected_adjustments.each do |category, expected_adjustment|
        adjustment = adjustments[category]
        expect(expected_adjustment).to be_within(0.01).of(adjustment[:delta])
      end
    end

    it 'can print a summary' do
      @analyzer.print_summary
    end

    it 'can weight the stocks' do
      summary = @analyzer.get_summary()
      holdings_by_category = summary[:holdings_by_category]
      expect(holdings_by_category.size).to eq(summary[:adjustments_by_category].size)
      expected_data = {:CdnEq=>
        {:RBF1015=>{:value=>0, :weight=>16.666666666666668},
          :CNR=>{:value=>1359.0, :weight=>16.666666666666668},
          :VFV=>{:value=>1588.0, :weight=>16.666666666666668},
          :SHOP=>{:value=>1325.0, :weight=>16.666666666666668},
          :ABX=>{:value=>3579.0, :weight=>16.666666666666668},
          :ENB=>{:value=>870.6, :weight=>16.666666666666668}},
        :USEq=>
          {:CTL=>{:value=>365.68322000000006, :weight=>25.0},
            :FIS=>{:value=>2070.52544, :weight=>25.0},
            :VOO=>{:value=>4103.79309, :weight=>25.0},
            :IRM=>{:value=>1320.99417, :weight=>25.0}},
        :IntlEq=>
          {:RBF1033=>{:value=>673.2, :weight=>50.0},
            :RBF1034=>{:value=>1072.95, :weight=>50.0}},
        :Resources=>
          {:RBF1037=>{:value=>377.19, :weight=>50.0},
            :SLV=>{:value=>977.71866, :weight=>50.0}},
        :Bonds=>{:VSB=>{:value=>49.02, :weight=>100.0}},
        :ShortTerm=>
          {:RBF1002=>{:value=>0, :weight=>25.0},
            :RBF1004=>{:value=>0, :weight=>25.0},
            :cash=>{:value=>641.52, :weight=>50.0}}}
      expected_data.each do |category, holdings|
        holdings.each do |symbol, block|
          expect(holdings_by_category[category][symbol][:value]).
            to be_within(0.001).of(block[:value]), "failed to match value of #{category}/#{symbol}, got #{block[:value]}"
          expect(summary[:holdings_by_category][category][symbol][:weight]).
            to be_within(0.001).of(block[:weight]), "failed to match weight of #{category}/#{symbol}, got #{block[:weight]}"
        end
      end
    end
  end

  describe 'stock not categorized' do

    before do
      dateObj = Date.parse('2020-08-15')
      fmt = "Holdings RBC01 %B %d, %Y.csv"
      glob = dateObj.strftime(fmt)
      rbc_paths = Dir.glob(File.join(@input_dir, glob))
      expect(rbc_paths.size).to eq(1)
      analyzer = Parsers::RBC::Analyzer.new
      entries = [analyzer.parse(rbc_paths[0])]

      sources = [
        {
          sourceName: :RBC,
          entries: entries
        },
      ]

      @analyzer = Analyze::Analyzer.new(File.join(@input_dir, "categories.yml"))
      @analyzer.process(sources)
    end

    it 'should assign the missing stock a zero weight' do
      summary = @analyzer.get_summary()
      uncategorized_equities = summary[:holdings_by_category][:UNCATEGORIZED]
      expect(uncategorized_equities).to include(:ORCL)
      expect(uncategorized_equities[:ORCL][:value]).to be_within(0.001).of(74.5156)
      expect(uncategorized_equities[:ORCL][:weight]).to eq(0)
    end
  end
end
