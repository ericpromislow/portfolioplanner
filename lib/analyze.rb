module Analyze

  class Analyzer
    def initialize(categories_file)
      @usrate = nil
      @cash = { USD: 0, CAD: 0 }
      @investments = { USD: 0, CAD: 0 }
      @totals = { USD: 0, CAD: 0 }
      @statedTotals = { USD: 0, CAD: 0 }
      @full_total = 0
      categories = YAML.load(IO.read(categories_file))
      @categories = categories.keys.map{|k| [k.to_s,0]}.to_h
      @category_by_symbol = {}
      categories.each do |category, symbols|
        symbols.each do |symbol|
          @category_by_symbol[symbol.to_s] = category
        end
      end
    end
    
    def process(investments)
      investments.each do |investment|
        investment[:entries].each do |entry|
          if !@usrate && entry[:usrate]
            @usrate = entry[:usrate]
          end

          # CASH
          
          cash_total = 0
          cdn_cash = entry[:cash][:CAD].to_f
          adjusted_cash_total = cdn_cash
          us_cash = entry[:cash][:USD].to_f
          if us_cash != 0
            if @usrate.nil?
              raise Exception.new("Awp: have uscash = #{us_cash} but no rate")
            end
            adjusted_cash_total += us_cash * @usrate
          end
          @cash[:CAD] += cdn_cash
          @cash[:USD] += us_cash
          @full_total += adjusted_cash_total
          @totals[:CAD] += cdn_cash
          @totals[:USD] += us_cash
          @categories["ShortTerm"] += adjusted_cash_total

          # STATED TOTALS

          entry[:statedTotals].each { |k, v| @statedTotals[k] += v.to_f }

          # Investments

          entry[:holdings].each do |holding|
            symbol = holding[:symbol]
            currency = holding[:currency].to_sym
            market_value = holding[:totalMarketValue].to_f
            if currency == :USD && @usrate.nil?
              raise Exception.new("Awp: have us currency but no us rate")
            end
            adjusted_market_value = currency == :USD ? market_value * @usrate : market_value
            category = @category_by_symbol.fetch(symbol)
            @categories[category] += adjusted_market_value
            @investments[currency] += market_value
            @full_total += adjusted_market_value
            @totals[currency] += market_value
          end
        end
      end

      def summary
        puts "Full total: #{commatize(@full_total)}"
        puts "category total check: #{commatize(@categories.values.sum)}"
        if @categories.values.sum.round != @full_total.round
          abort("full-total check error")
        end
        puts "Current ratios:"
        full_ratio = 0
        @categories.each do |key, value|
          ratio = value/@full_total
          full_ratio += ratio
          printf("%s: %02.02f%%\n", key, ratio * 100)
        end
        if (full_ratio - 1.0).abs > 0.1
          abort "Ended up with a full_ratio of #{full_ratio}"
        end
        printf("%20s   %8s   %8s\n", "", "CAD", "US", "value")
        %w/cash investments totals statedTotals/.each do | name |
          var = instance_eval("@#{name}")
          printf("%20s  %10s  %10s\n", name, commatize(var[:CAD]), commatize(var[:USD]))
        end
        puts("categories")
        @categories.each do |category, total|
          printf("%20s %12s % 8.02f%%\n", category, commatize(total), 100 * (total/@full_total))
        end
      end
          
    end
  end
end
