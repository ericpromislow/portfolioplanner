# encoding: utf-8
# parse rbc cvs files, return a hash 

require 'base_parser'
require 'csv'

# states:
# 1: initial, default
# 2: saw Account
# 3: in 2, saw Exchange Rate
# 4: Saw Currency,Cash,Inv header
# 5: in 4, saw .../Product/Symbol

module Parsers
  class RBC < BaseParser

    FileNameGlobFormat = "Holdings [A-Z0-9]* %B %-d, %Y.csv"

    def fixSymbol(path)
      contents = IO.read(path, encoding:'bom|utf-8')
      # c2 = contents.sub(/function Symbol\(\)\s+\{.*?\},/mu, 'Symbol,')
      c2 = contents.sub(/,Product,function.+?,Name,/mu, ',Product,Symbol,Name,')
      if c2.size == contents.size
        $stderr.puts("*** Hey prob no need to fix symbols now")
      end
      return c2
    end

    def parse(path)
      entry = createEntry()
      total_idx = 3
      state = 1
      CSV.parse(fixSymbol(path)) do |row|
      # lines = fixSymbol(path)
      # CSV.foreach(path, encoding:'bom|utf-8', skip_lines: /"Holdings Export as of \w+ \d+, \d+ [\d:]+ \wM ET"/) do |row|
        next if row.size == 0
        next if row[0..10].all?(&:nil?)
        if state == 1
          if m = (row[0] || "").match(/Account: (\w+) - (\w+)/)
            entry[:accountName] = m[2]
            entry[:accountNum] = m[1]
            state = 2
          end
        elsif state == 2 || state == 3 
          if state == 2 && row[0] =~ /Exchange Rate: 1 USD = ([\d\.]+) CAD/
            entry[:usrate] = $1.to_f
            state = 3
            continue
          end
          if row[0..2].join(',') == 'Currency,Cash,Investments'
            total_idx = row.find_index("Total")
            state = 4
          end
        elsif state == 4
          if row.size > 20 && row[1] == "Product" && row[2] == "Symbol"
            state = 5
            next
          end
          currency = row[0].to_sym
          cash_total = row[1].to_f
          entry[:cash][currency] = row[1]
          entry[:stated_totals][currency] = row[total_idx]
          entry[:stated_investments][currency] = row[2]
          if row[0] == 'USD'
            entry[:usrate] = row[4].to_f            
          end
        elsif state == 5
          break if row[0] == "Important Information"
          if row.size > 20
            entry[:holdings] << {
              type: row[1],
              symbol: row[2],
              quantity: row[4],
              price: row[5],
              currency: row[6],
              totalMarketValue: row[10],
            }
          end
        end
      end
      return entry
    end

  end
end
