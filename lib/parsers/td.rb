# parse td cvs files, return an entry

require 'parsers/common'
require 'csv'

module Parsers
  module TD

    FileNameGlobFormat = "[A-Z0-9]*-holdings-%d-%b-%Y.csv"

    class Analyzer < Common::Analyzer
      def parse(path)
        entry = createEntry()
        state = 1
        currency = :CAD
        CSV.foreach(path) do |row|
          next if row.size == 0
          next if row[0..10].all?(&:nil?)
          if state == 1
            if row[0] == "Account"
              if m = row[1].match(/TD (Direct Investing) . (\w+)/) # not a dash, but an 0x8211 chr
                entry[:accountName] = m[1]
                entry[:accountNum] = m[2]
              else
                raise Exception.new("Failed to match account info in #{row}")
              end
            elsif row[0] == "Cash"
              entry[:cash][currency] = row[1]
            elsif row[0] == "Total Value"
              entry[:stated_totals][currency] = row[1]
            elsif row[0] == "Investments"
              entry[:stated_investments][currency] = row[1]
            elsif row.size > 20 && row[0] == "Symbol" && row[1] == "Market"
              state = 2
            end
          elsif state == 2 && row.size > 20
            entry[:holdings] << {
              type: :Stock,
              symbol: row[0],
              quantity: row[3],
              price: row[5],
              currency: row[1] == "CA" ? :CAD : :USD,
              totalMarketValue: row[7],
            }
          end
        end
        return entry
      end
    end
  end
end
    
