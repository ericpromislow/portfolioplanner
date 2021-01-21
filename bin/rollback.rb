#!/usr/bin/env ruby

# get and parse csv files for the specified date
# emit a bunch of yaml

require 'date'
require 'optparse'
require 'yaml'

$: << File.expand_path("../lib", File.dirname($0))

require 'common'

require 'date_total_db'
require 'spreadsheet'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{$0} [options]"

  options[:inputDir] = File.expand_path("../data", File.dirname($0))
  opts.on('-i', '--input-dir DIR', 'read csv files from DIR') { |dir| options[:inputDir] = dir }

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

db_path = File.join(options[:inputDir] , "totals.db")
db = SQLite3::Database.open(db_path);

begin
  rows = db.execute("select max(chart_date) from totals")
  max_date = rows[0][0]
  puts "Deleting row for date #{max_date}..."
  db.execute("delete from totals where chart_date = #{max_date}")
ensure
  db.close
end
