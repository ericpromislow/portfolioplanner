module Analyze

  class Analyzer
    def initialize(categories_file)
      @usrate = nil
      @cash = { USD: 0, CAD: 0 }
      @investments = { USD: 0, CAD: 0 }
      @totals = { USD: 0, CAD: 0 }
      @statedTotals = { USD: 0, CAD: 0 }
      @statedInvestments = { USD: 0, CAD: 0 }
      @full_total = 0
      @desired_weights_by_category = {}
      @total_desired_weights = 0
      categories = YAML.load(IO.read(categories_file))
      @categories = categories.keys.map{|k| [k.to_s,0]}.to_h
      @category_by_symbol = {}
      categories.each do |category, entry|
        entry['symbols'].each do |symbol|
          @category_by_symbol[symbol.to_s] = category
        end
        desired_weight = entry['desired_weight'].to_f
        @total_desired_weights += desired_weight
        @desired_weights_by_category[category.to_sym] = desired_weight
      end
      total_desired_weights = @desired_weights_by_category.values.sum
      if total_desired_weights != 100
        @desired_weights_by_category.each do |k, v|
          @desired_weights_by_category[k] = v/ total_desired_weights
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
          entry[:statedInvestments].each { |k, v| @statedInvestments[k] += v.to_f }

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
        printf("%20s   %8s   %8s\n", "", "CAD", "US", "value")
        %w/cash investments statedInvestments totals statedTotals/.each do | name |
          var = instance_eval("@#{name}")
          printf("%20s  %10s  %10s\n", name, commatize(var[:CAD]), commatize(var[:USD]))
        end
        puts("\n#{'=' * 50}\ncategories")
        printf("%20s   %8s   %8s  %8s  %8s\n", "category", 'amount', 'actual %', 'desired %', 'delta')
        running_deltas = 0
        full_ratio = 0
        @categories.each do |category, total|
          actualFraction = total/@full_total
          full_ratio += actualFraction
          desiredPercentage = @desired_weights_by_category[category.to_sym]
          desiredFraction = desiredPercentage / 100
          delta = @full_total * (desiredFraction - actualFraction)
          running_deltas += delta
          printf("%20s %12s % 8.02f%% % 8.02f%%  %8.2f\n",
                 category,
                 commatize(total),
                 100 * actualFraction,
                 100 * desiredFraction,
                 delta)
        end
        if (full_ratio - 1.0).abs > 0.1
          abort "Ended up with a full_ratio of #{full_ratio}"
        end
        if running_deltas.abs > 0.01
          puts "Hey! sum of changes = #{running_deltas}"
        end
      end
          
    end
  end
end
