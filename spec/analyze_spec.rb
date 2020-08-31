require 'rspec'
require 'date'
require 'yaml'

require 'analyze'
require 'common'
require 'plugin_manager'

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

      sources = []
      PluginManager.each do |className, analyzerClass|
        glob = dateObj.strftime(analyzerClass.const_get(:FileNameGlobFormat).sub(/\.csv\z/, '.yml'))
        paths = Dir.glob(File.join(@input_dir, glob))
        sources << {
          sourceName: className,
          entries: paths.map {|path| deep_symbolize_keys(YAML.load_file(path))}
        }
      end
      expect(sources.size).to eq(3)
      expect(sources.sum {|source| source[:entries].size}).to eq(5)
      expect(sources.find{|src| src[:sourceName] == :ManuLife}[:entries].size).to eq(0)

      @analyzer = Analyze::Analyzer.new(File.join(@input_dir, "categories.yml"))
      @analyzer.process(sources)
    end

    it 'should get the summary' do
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
      expected_adjustments = {:CdnEq=>-5772.27,
        :USEq=>-3928.55,
        :IntlEq=>-173.17,
        :Resources=>21.45,
        :Bonds=>4669.91,
        :ShortTerm=>2949.33,
        :CASH => 2307.81,
        :UNCATEGORIZED=>-74.52}


      expected_adjustments.each do |category, expected_adjustment|
        adjustment = adjustments[category]
        expect(expected_adjustment).to be_within(0.01).of(adjustment[:delta])
      end
    end

    it 'can print a summary' do
      expect {
        @analyzer.print_summary
      }.to output(/ORCL           74.52                0.00%       -74.52/).to_stdout
    end

    it 'can weight the stocks' do
      summary = @analyzer.get_summary()
      holdings_by_category = summary[:holdings_by_category]
      expect(holdings_by_category.size).to eq(summary[:adjustments_by_category].size)
      expected_data = {:CdnEq=>
        {:RBF1015=>
          {:value=>0, :weight=>16.666666666666668, :delta=>491.555528846154},
          :CNR=>
            {:value=>1359.0, :weight=>16.666666666666668, :delta=>-867.444471153846},
          :VFV=>
            {:value=>1588.0, :weight=>16.666666666666668, :delta=>-1096.444471153846},
          :SHOP=>
            {:value=>1325.0, :weight=>16.666666666666668, :delta=>-833.444471153846},
          :ABX=>
            {:value=>3579.0, :weight=>16.666666666666668, :delta=>-3087.444471153846},
          :ENB=>
            {:value=>870.6, :weight=>16.666666666666668, :delta=>-379.044471153846}},
        :USEq=>
          {:CTL=>
            {:value=>365.68322000000006, :weight=>25.0, :delta=>617.4278376923082},
            :FIS=>{:value=>2070.52544, :weight=>25.0, :delta=>-1087.4143823076915},
            :VOO=>{:value=>4103.79309, :weight=>25.0, :delta=>-3120.6820323076918},
            :IRM=>{:value=>1320.99417, :weight=>25.0, :delta=>-337.8831123076917}},
        :IntlEq=>
          {:RBF1033=>{:value=>673.2, :weight=>50.0, :delta=>113.28884615384641},
            :RBF1034=>{:value=>1072.95, :weight=>50.0, :delta=>-286.4611538461536}},
        :Resources=>
          {:RBF1037=>{:value=>377.19, :weight=>50.0, :delta=>310.9877403846156},
            :SLV=>{:value=>977.71866, :weight=>50.0, :delta=>-289.5409196153844}},
        :Bonds=>{:VSB=>{:value=>49.02, :weight=>100.0, :delta=>4669.913076923078}},
        :ShortTerm=>
          {:RBF1002=>{:value=>0, :weight=>50.0, :delta=>1474.6665865384618},
            :RBF1004=>{:value=>0, :weight=>50.0, :delta=>1474.6665865384618},},
        :CASH =>
          {
            :cash=>{:value=>641.51984, :weight=>100.0, :delta=>2307.8133330769238},
          },

        :UNCATEGORIZED=>
          {:ORCL=>{:value=>74.51558000000001, :weight=>0, :delta=>-74.51558000000001}}}
      expected_data.each do |category, holdings|
        holdings.each do |symbol, block|
          expect(holdings_by_category[category][symbol][:value]).
            to be_within(0.01).of(block[:value]), "failed to match value of #{category}/#{symbol}, got #{holdings_by_category[category][symbol][:value]}"
          expect(holdings_by_category[category][symbol][:weight]).
            to be_within(0.01).of(block[:weight]), "failed to match weight of #{category}/#{symbol}, got #{holdings_by_category[category][symbol][:weight]}"
          expect(holdings_by_category[category][symbol][:delta]).
            to be_within(0.01).of(block[:delta]), "failed to match delta of #{category}/#{symbol}, got #{holdings_by_category[category][symbol][:delta]}"
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
      analyzer = PluginManager[:RBC].new
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
