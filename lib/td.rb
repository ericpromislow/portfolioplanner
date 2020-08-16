# parse td cvs files, return an entry

require 'common'
require 'csv'

module TD

  class Analyzer < Common::Analyzer
    def parse(path)
      entry = createEntry()
      state = 1
      currency = :CAD
      CSV.foreach(path) do |row|
        next if row.size == 0
        if state == 1
          if row[0] == "Account"
            if m = row[1].match(/TD (Direct Investing) - (\w+)/)
              entry[:accountName] = m[1]
              entry[:accountNum] = m[2]
            else
              raise Exception.new("Failed to match account info in #{row}")
            end
          elsif row[0] == "Cash"
            entry[:cash][currency] = row[1]
          elsif row[0] == "Total Value"
            entry[:statedTotals][currency] = row[1]
          elsif row[0] == "Investments"
            entry[:statedInvestments][currency] = row[1]
          elsif row.size > 20 && row[0] == "Symbol" && row[1] == "Market"
            state =2
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
    
