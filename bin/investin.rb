#!/usr/bin/env ruby

# get and parse csv files for the specified date
# emit a bunch of yaml

# Typical command:
# rm -f tmp/totals.ods
# ruby ./bin/investin.rb -d YYYY-MM-DD -n 6 -s tmp/full-summary-YYYY-MM-DDa.ods
# rm -f tmp/totals.ods ; ruby bin/investin.rb -d 2021-06-27 -n 6 -s tmp/full-summary-2021-06-27a.ods

require 'date'
require 'optparse'
require 'yaml'

VERSION='1.0.0'

$: << File.expand_path("../lib", File.dirname($0))

require 'common'

require 'plugin_manager'
require 'analyze'
require 'date_total_db'
require 'spreadsheet'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{$0} [options]"

  options[:date] = Date.today.to_s
  opts.on('-d', '--date STRING', 'read info for date yyyy-mm-dd') do |date|
    if /\A\d{4}-\d{2}-\d{2}\z/ !~ date
      usage("Error: invalid date format: '#{date}'")
    end
    options[:date] = date
  end

  options[:inputDir] = File.expand_path("../data", File.dirname($0))
  opts.on('-i', '--input-dir DIR', 'read csv files from DIR') { |dir| options[:inputDir] = dir }

  options[:categories] = File.expand_path("../categories.yml", File.dirname($0))
  opts.on('-c', '--categories FILE', 'read categories from FILE') { |path| options[:categories] = path }

  options[:minSources] = 0
  opts.on('-n', '--minimum-sources INTEGER', 'min # sources to read') { |min|
    options[:minSources] = min.to_i
  }

  options[:summary] = false
  opts.on('--summary', 'emit a summary to stdout') { options[:summary] = true }

  options[:spreadsheet] = nil
  opts.on('-s', '--spreadsheet FILE', 'emit the spreadsheet to DIR/PATH') { |path| options[:spreadsheet] = path }

  options[:forceOverwrite] = false
  opts.on('-f', '--force-overwrite', 'overwrite existing spreadsheet') { options[:forceOverwrite] = true }

  opts.on('-v', '--version') do
    puts VERSION
    exit 0
  end

  opts.on('-h', '--help') do
    puts opts
    exit 1
  end
end

def usage(message)
  $stderr.puts(message)
  $stderr.puts `ruby "#{$0}" -h`
  exit 1
end

begin
  optparse.parse!
rescue => ex
  if ex.class.to_s.start_with?("OptionParser")
    usage(ex.message)
  end
end

if ARGV.size > 0
  usage "Unhandled args: #{ARGV}"
end

if options[:forceOverwrite] && options[:spreadsheet].nil?
  usage("Need to specify -s/--spreadsheet when --force-overwrite is specified")
end

if options[:spreadsheet].nil? && !options[:summary]
  options[:summary] = true
end
# pp options

date=options[:date]
dateObj = Date.parse(date)
input_dir = options[:inputDir]
categories_file = options[:categories]

sources = []
PluginManager.each do |analyzerName, analyzerClass|
  glob = dateObj.strftime(analyzerClass.const_get(:FileNameGlobFormat))
  paths = Dir.glob(File.join(input_dir, glob))
  if paths.size == 0
    altGlobFormat = analyzerClass.const_get(:FileNameGlobFormatBackup) rescue nil
    next if !altGlobFormat
    glob = dateObj.strftime(altGlobFormat)
    paths = Dir.glob(File.join(input_dir, glob))
    next if paths.size == 0
  end

  sources << {
    sourceName: analyzerName,
    entries: paths.map { |path| deep_symbolize_keys(analyzerClass.new.parse(path)) },
  }
end
total_paths = sources.map{|s| s[:entries].size }.sum
if total_paths == 0
  abort "No input for date #{date}"
elsif total_paths < options[:minSources]
  abort "Expecting at least #{options[:minSources]} sources, only got #{total_paths}"
end

analyzer = Analyze::Analyzer.new(categories_file)
analyzer.process(sources)

if options[:summary]
  analyzer.print_summary
end

if (spreadsheet_location = options[:spreadsheet])
  if File.directory?(spreadsheet_location)
    path = File.join(spreadsheet_location, "full-summary-#{dateObj}.ods")
    totals_path = File.join(spreadsheet_location, "totals.ods")
  else
    path = spreadsheet_location
    totals_path = File.join(File.dirname(spreadsheet_location), "totals.ods")
  end
  if File.exist?(path) && !options[:forceOverwrite]
    puts "File #{path} already exists. Run with -f to overwrite"
    exit 0
  end
  spreadsheeter = Spreadsheet.new
  spreadsheeter.create(path, analyzer)
  system(%Q/open "#{path}"/)

  total = analyzer.get_total
  db = DateTotalDatabase.new(input_dir, "totals.db")
  begin
    db.add(date, total)
    t1 = Time.now
    spreadsheeter.update_totals(db, totals_path)
    t2 = Time.now
    puts "Time to update totals: #{ (t2 - t1) } secs"
    system(%Q/open "#{totals_path}"/)
  ensure
    db.close
  end

end

