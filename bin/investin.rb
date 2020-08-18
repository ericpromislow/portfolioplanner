#!/usr/bin/env ruby

# get and parse csv files for the specified date
# emit a bunch of yaml

require 'date'
require 'yaml'

$: << File.expand_path("../lib", File.dirname($0))

require 'common'

# If this is going anywhere all the inputs will be based on plugins, not hardwired, 
# and then we'll loop on them.
require 'parsers/rbc'
require 'parsers/td'
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


glob = dateObj.strftime(Parsers::RBC::FileNameGlobFormat)
rbc_paths = Dir.glob(File.join(input_dir, glob))
usage("No rbc files for date #{date}") if rbc_paths.size == 0
glob = dateObj.strftime(Parsers::TD::FileNameGlobFormat)
td_paths = Dir.glob(File.join(input_dir, glob))
usage("No td files for date #{date}") if td_paths.size == 0

source = {
    sourceName: :RBC,
    entries: []
  }
sources = [
  source
]
rbc_analyzer = Parsers::RBC::Analyzer.new
rbc_paths.each do |path|
  source[:entries] << rbc_analyzer.parse(path)
end

source = {
    sourceName: :TD,
    entries: []
  }
td_analyzer = Parsers::TD::Analyzer.new
td_paths.each do |path|
  source[:entries] << td_analyzer.parse(path)
end
sources << source
sources = deep_symbolize_keys(sources)

analyzer = Analyze::Analyzer.new("categories.yml")
analyzer.process(sources)
analyzer.print_summary
