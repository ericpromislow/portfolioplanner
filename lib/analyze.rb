module Analyze

  class Analyzer
    def initialize(categories_file)
      @usrate = nil
      @cash = { USD: 0, CAD: 0 }
      @investments = { USD: 0, CAD: 0 }
      @totals = { USD: 0, CAD: 0 }
      @stated_totals = { USD: 0, CAD: 0 }
      @stated_investments = { USD: 0, CAD: 0 }
      @full_total = 0
      @desired_weights_by_category = {}
      @total_desired_weights = 0
      data = deep_symbolize_keys(YAML.load(IO.read(categories_file)))
      @categories = data.keys.map{|k| [k, 0]}.to_h
      @category_by_symbol = {}
      weight_by_symbol = {}
      @holdings_by_category = {}

      data.each do |category, entry|
        @holdings_by_category[category] ||= Hash.new {|hash, key| hash[key] = {value:0}}
        total_weight = 0
        weighted_symbols = entry[:symbols]
        weighted_symbols.each do |weighted_symbol|
          symbol = weighted_symbol[:symbol].to_sym
          @category_by_symbol[symbol] = category
          @holdings_by_category[category][symbol][:weight] = weighted_symbol[:desired_weight]
          weight_by_symbol[symbol] = weighted_symbol[:desired_weight]
          total_weight += weighted_symbol[:desired_weight]
        end
        if (total_weight - 100.0).abs > 0.001
          weighted_symbols.each do |weighted_symbol|
            symbol = weighted_symbol[:symbol].to_sym
            @holdings_by_category[category][symbol][:weight] = 100.0 * weight_by_symbol[symbol] / total_weight
          end
        end
        desired_weight = entry.fetch(:desired_weight).to_f
        @total_desired_weights += desired_weight
        @desired_weights_by_category[category.to_sym] = desired_weight
      end

      total_desired_weights = @desired_weights_by_category.values.sum
      if total_desired_weights != 100
        @desired_weights_by_category.each do |k, v|
          @desired_weights_by_category[k] = (v/ total_desired_weights) * 100
        end
      end
    end

    def holding_default_hash
      Hash.new {|hash, key| hash[key] = {value:0, weight:0}}
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
          @categories[:ShortTerm] += adjusted_cash_total
          @holdings_by_category[:ShortTerm][:cash][:value] += adjusted_cash_total

          # STATED TOTALS

          entry[:stated_totals].each { |k, v| @stated_totals[k] += v.to_f }
          entry[:stated_investments].each { |k, v| @stated_investments[k] += v.to_f }

          # Investments

          entry[:holdings].each do |holding|
            symbol = holding[:symbol].to_sym
            currency = holding[:currency].to_sym
            market_value = holding[:totalMarketValue].to_f
            if currency == :USD && @usrate.nil?
              raise Exception.new("Awp: have us currency but no us rate")
            end
            adjusted_market_value = currency == :USD ? market_value * @usrate : market_value
            category = @category_by_symbol.fetch(symbol)
            @categories[category] += adjusted_market_value

            @holdings_by_category[category][symbol][:value] += adjusted_market_value
            @investments[currency] += market_value
            @full_total += adjusted_market_value
            @totals[currency] += market_value
          end
        end
      end

      def get_summary
        data = {
          full_total: @full_total,
          total_check_by_category: @categories.values.sum,
          adjustments_by_category: [],
          holdings_by_category: {},
        }
        if (@full_total - data[:total_check_by_category]).abs > 0.001
          abort("full-total check error")
        end
        h = {}
        %w/cash investments stated_investments totals stated_totals/.each do |name|
          var = instance_eval("@#{name}")
          h[name.to_sym] = {
            CAD: var[:CAD],
            USD: var[:USD],
          }
        end
        data[:totals_by_category] = h

        full_ratio = 0.0
        running_deltas = 0.0
        h = {}
        @categories.each do |category, total|
          actualFraction = total/@full_total
          full_ratio += actualFraction
          desiredPercentage = @desired_weights_by_category[category]
          desiredFraction = desiredPercentage / 100
          delta = @full_total * (desiredFraction - actualFraction)
          running_deltas += delta
          h[category] = {
            total: total,
            actualFraction: actualFraction,
            desiredFraction: desiredFraction,
            delta: delta,
          }
          data[:holdings_by_category][category] = @holdings_by_category[category]
        end
        if (full_ratio - 1.0).abs > 0.1
          abort "Ended up with a full_ratio of #{full_ratio}"
        end
        if running_deltas.abs > 0.01
          puts "Hey! sum of changes = #{running_deltas}"
        end
        data[:adjustments_by_category] = h

        return data
      end

      def print_summary(summary=nil)
        summary = get_summary() if summary.nil?
        puts "Full total: #{commatize(summary[:full_total])}"
        puts ""
        printf("%20s   %8s   %8s\n", "", "CAD", "US", "value")
        %i/cash investments totals /.each do | name |
          var = summary[:totals_by_category][name]
          printf("%20s  %10s  %10s\n", name, commatize(var[:CAD]), commatize(var[:USD]))
          stated_name = "stated_#{name}"
          stated_var = summary[:totals_by_category][stated_name]
          if stated_var && ((stated_var[:CAD] - var[:CAD]).abs > 0.001 ||
            (stated_var[:USD] - var[:USD]).abs > 0.001)
            printf("%20s  %10s  %10s\n", name, commatize(stated_var[:CAD]), commatize(stated_var[:USD]))
          end
        end
        puts("\n#{'=' * 50}\ncategories")
        printf("%20s   %8s   %8s  %8s  %8s\n", "category", 'amount', 'actual %', 'desired %', 'delta')
        summary[:adjustments_by_category].each do |category, adjustment|
          printf("%20s %12s % 8.02f%% % 8.02f%%  %8.2f\n",
            category,
            commatize(adjustment[:total]),
            100 * adjustment[:actualFraction],
            100 * adjustment[:desiredFraction],
            adjustment[:delta])
        end
      end
          
    end
  end
end
