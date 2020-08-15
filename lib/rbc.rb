# parse rbc cvs files, return a hash 

require 'common'
require 'csv'

module RBC

  class Analyzer < Common::Analyzer
    def parse(path)
      entry = createEntry()
      total_idx = 3
      state = 1
      CSV.foreach(path, skip_lines:/"Holdings Export as of \w+ \d+, \d+ [\d:]+ \wM ET"/) do |row|
        next if row.size == 0
        if state == 1
          if m = row[0].match(/Account: (\d+) - (\w+)/)
            entry[:accountName] = m[2]
            entry[:accountNum] = m[1]
            state = 2
          end
        elsif state == 2
          if row[0] =~ /Exchange Rate: 1 USD = ([\d\.]+) CAD/
            entry[:usrate] = $1.to_f
            state = 3
          end
        elsif state == 3
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
          entry[:cash][row[0]] = row[1]
          entry[:statedTotals][row[0]] = row[total_idx]
        elsif state == 5
          break if row[0] == "Important Information"
          if row.size > 20
            entry[:holdings] << {
              type: row[1],
              symbol: row[2],
              quantity: row[4],
              price: row[5],
              currency: row[6],
              totalMarketValue: row[9],
            }
          end
        end
      end
      return entry
    end
  end

end
