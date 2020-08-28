require 'rspec'
require 'yaml'

require 'analyze'
require 'common'
require 'plugin_manager'
require 'spreadsheet'

describe Spreadsheet do

  before do
    @spec_dir = File.dirname(__FILE__)
    @base_dir = File.absolute_path(File.dirname(@spec_dir))
    $:.push(File.join(@base_dir, "lib"))
    @input_dir = File.join(@base_dir, "test/fixtures")
    @tmp_dir = File.join(@base_dir, "tmp")do
    end
  end

  it 'should create a simple spreadsheet' do
    workbook = Rspreadsheet.new
    worksheet = workbook.create_worksheet
    worksheet.cell('A1').value = 3
    worksheet.cell('A2').value = 5
    worksheet.cell('A3').formula = "=A1+A2"
    expect {
      workbook.save(File.join(@tmp_dir, "test.ods"))
    }.to_not raise_exception
  end

  describe 'loading the data' do
    before do
      dateObj = Date.parse('2020-08-15')
      @path = File.join(@tmp_dir, "summary-#{dateObj}.ods")

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

      @analyzer = Analyze::Analyzer.new(File.join(@input_dir, "categories.yml"))
      @analyzer.process(sources)
    end

    it 'can write to a spreadsheet' do
      spreadsheet = Spreadsheet.new
      spreadsheet.create(@path, @analyzer)
    end
  end
end
