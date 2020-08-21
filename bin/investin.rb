#!/usr/bin/env ruby

# get and parse csv files for the specified date
# emit a bunch of yaml

require 'date'
require 'yaml'

$: << File.expand_path("../lib", File.dirname($0))

require 'common'

require 'plugin_manager'
require 'analyze'

def usage(msg=nil)
  $stderr.puts "Usage #{$0} yyyy-mm-dd inputDir"
  $stderr.puts msg if msg
  exit 1
end

if ARGV.size < 2
  usage("not enough args")
end

date=ARGV[0]
input_dir = ARGV[1]
dateObj = Date.parse(date)

sources = []
PluginManager.each do |analyzerName, analyzerClass|
  glob = dateObj.strftime(analyzerClass.const_get(:FileNameGlobFormat))
  paths = Dir.glob(File.join(input_dir, glob))
  next if paths.size == 0

  sources << {
    sourceName: analyzerName,
    entries: paths.map { |path| deep_symbolize_keys(analyzerClass.new.parse(path)) },
  }
end

analyzer = Analyze::Analyzer.new("categories.yml")
analyzer.process(sources)
analyzer.print_summary
