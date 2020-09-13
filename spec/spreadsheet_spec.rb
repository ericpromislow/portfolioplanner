require 'rspec'
require 'yaml'

require 'analyze'
require 'common'
require 'plugin_manager'
require 'spreadsheet'

describe Spreadsheet do
  let(:date_obj) { Date.parse('2020-08-15') }
  let(:spec_dir) { File.dirname(__FILE__) }
  let(:base_dir) { File.absolute_path(File.dirname(spec_dir)) }
  let(:tmp_dir) { File.join(base_dir, "tmp") }
  let(:path) { File.join(tmp_dir, "summary-#{date_obj}.ods") }

  describe 'simple' do
    it 'should create a simple spreadsheet' do
      workbook = Rspreadsheet.new
      worksheet = workbook.create_worksheet
      worksheet.cell('A1').value = 3
      worksheet.cell('A2').value = 5
      worksheet.cell('A3').formula = "=A1+A2"
      expect {
        workbook.save(File.join(tmp_dir, "test.ods"))
      }.to_not raise_exception
    end
  end

  describe 'processing' do

    before do
      $:.push(File.join(base_dir, "lib"))

      sources = []
      PluginManager.each do |className, analyzerClass|
        glob = date_obj.strftime(analyzerClass.const_get(:FileNameGlobFormat).sub(/\.csv\z/, '.yml'))
        paths = Dir.glob(File.join(input_dir, glob))
        sources << {
          sourceName: className,
          entries: paths.map {|path| deep_symbolize_keys(YAML.load_file(path))}
        }
      end
      expect(sources.size).to eq(3)
      expect(sources.sum {|source| source[:entries].size}).to eq(num_sources)

      @analyzer = Analyze::Analyzer.new(File.join(input_dir, "categories.yml"))
      @analyzer.process(sources)
    end

    describe 'weight everything' do
      let(:input_dir) { File.join(base_dir, "test/fixtures") }
      let(:num_sources) { 5 }

      it 'can write to a spreadsheet' do
        spreadsheet = Spreadsheet.new
        spreadsheet.create(path, @analyzer)
      end

    end

    describe 'include ignorables' do
      let(:input_dir) { File.join(base_dir, "test/ignorable_fixtures") }
      let(:num_sources) { 1 }

      it 'can write to a spreadsheet' do
        spreadsheet = Spreadsheet.new
        spreadsheet.create(path, @analyzer)
      end
    end
  end


end
