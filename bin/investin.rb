#!/usr/bin/env ruby

# get and parse csv files for the specified date
# emit a bunch of yaml

require 'date'
require 'yaml'

$: << File.expand_path("../lib", File.dirname($0))

require 'common'

# If this is going anywhere all the inputs will be based on plugins, not hardwired, 
# and then we'll loop on them.
require 'rbc'
require 'td'
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
inputDir = ARGV[1]
dateObj = Date.parse(date)

rbc_paths = Dir.glob("#{inputDir}/Holdings [0-9]* #{dateObj.strftime('%B %d, %Y')}.csv")
usage("No rbc files for date #{date}") if rbc_paths.size == 0
td_paths = Dir.glob("#{inputDir}/[0-9A-Z]*-holdings-#{dateObj.strftime('%d-%b-%Y')}.csv")
usage("No td files for date #{date}") if td_paths.size == 0

source = {
    sourceName: :RBC,
    entries: []
  }
sources = [
  source
]
rbc_analyzer = RBC::Analyzer.new
rbc_paths.each do |path|
  source[:entries] << rbc_analyzer.parse(path)
end

source = {
    sourceName: :TD,
    entries: []
  }
td_analyzer = TD::Analyzer.new
td_paths.each do |path|
  source[:entries] << td_analyzer.parse(path)
end
sources << source
sources = deep_symbolize_keys(sources)

analyzer = Analyze::Analyzer.new("categories.yml")
analyzer.process(sources)
analyzer.summary
