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
      @ignorable_total = 0
      @desired_weights_by_category = {}
      @total_desired_weights = 0
      data = deep_symbolize_keys(YAML.load(IO.read(categories_file)))
      @categories = data.keys.map{|k| [k, 0]}.to_h
      @category_by_symbol = { cash: :CASH }
      @position_by_category = {}
      weight_by_symbol = {}
      @holdings_by_category = {
        UNCATEGORIZED: Hash.new {|hash, key| hash[key] = {value:0}},
        CASH: { cash: { value: 0, weight: 100 }}
      }

      # Handle uncategorized entries
      @categories[:UNCATEGORIZED] = 0
      @desired_weights_by_category[:UNCATEGORIZED] = 0

      data.each do |category, entry|
        @position_by_category[category] = entry[:position]
        @holdings_by_category[category] ||= Hash.new {|hash, key| hash[key] = {value:0}}
        weighted_symbols = entry[:symbols] || []
        if category == :TRADES
          # These aren't weighted
          weighted_symbols.each do |weighted_symbol|
            symbol = weighted_symbol[:symbol].to_sym
            @category_by_symbol[symbol] = category
            @holdings_by_category[category][symbol][:weight] = 0
          end
        else
          total_weight = 0
          weighted_symbols.each do |weighted_symbol|
            symbol = weighted_symbol[:symbol].to_sym
            @category_by_symbol[symbol] = category
            desired_weight = weighted_symbol[:desired_weight] || 1
            @holdings_by_category[category][symbol][:weight] = desired_weight
            weight_by_symbol[symbol] = desired_weight
            total_weight += desired_weight
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
          if !@usrate && entry[:usrate].to_f != 0
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
          @categories[:CASH] += adjusted_cash_total
          @holdings_by_category[:CASH][:cash][:value] += adjusted_cash_total

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
            category = @category_by_symbol[symbol] || :UNCATEGORIZED
            @categories[category] += adjusted_market_value

            @holdings_by_category[category][symbol][:value] += adjusted_market_value
            if @category_by_symbol[symbol].nil?
              @holdings_by_category[category][symbol][:weight] = 0
            end
            @investments[currency] += market_value
            @full_total += adjusted_market_value
            if category == :TRADES
              @ignorable_total += adjusted_market_value
            end
            @totals[currency] += market_value
          end
        end
      end

      def get_summary
        data = {
          full_total: @full_total,
          ignorable_total: @ignorable_total,
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
        active_full_total = @full_total - @ignorable_total
        if active_full_total == 0
          abort("Nothing to summarize. Go buy some stocks or something.")
        end
        @categories.each do |category, total|
          if category == :TRADES
            h[category] = {
              total: total,
            }
          else
            next if category == :TRADES
            actual_fraction = total/active_full_total
            full_ratio += actual_fraction
            desired_percentage = @desired_weights_by_category[category]
            desired_fraction = desired_percentage / 100
            desired_total_for_category = active_full_total * desired_fraction
            delta_for_category = active_full_total * (desired_fraction - actual_fraction)
            running_deltas += delta_for_category
            h[category] = {
              total: total,
              actualFraction: actual_fraction,
              desiredFraction: desired_fraction,
              delta: delta_for_category,
            }

            # Readjust the delta's for each holding
            running_delta_for_category = 0
            @holdings_by_category[category].each do | symbol, holding_data |
              current_value = holding_data[:value]
              begin
              desired_value = holding_data[:weight]/100.0 * desired_total_for_category
              rescue NoMethodError
                if symbol == :cash && holding_data[:weight].nil?
                  $stderr.puts("You need to put an entry for 'cash' in the categories file")
                  exit 2
                end
              end

              delta_for_holding = desired_value - current_value
              holding_data[:delta] = delta_for_holding
              running_delta_for_category += delta_for_holding
            end
            if (running_delta_for_category - delta_for_category).abs > 0.01
              raise Exception.new("running_delta_for_category for category #{category} is #{running_delta_for_category}, should be #{delta_for_category}")
            end
          end
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

      def sorted_categories(summary)
        decorated_keys = summary[:adjustments_by_category].keys.map { |k| [@position_by_category[k], k]}
        decorated_keys.sort do |h1, h2|
          pos1 = h1[0]
          pos2 = h2[0]
          if pos1
            if pos2
              pos1 <=> pos2
            else
              -1
            end
          elsif pos2
            1
          elsif h1[1] == :UNCATEGORIZED
            1
          elsif h2[1] == :UNCATEGORIZED
            -1
          else
            h1[1] <=> h2[1]
          end
        end.map { |pos, key| key}
      end

      def get_total
        return @full_total
      end

      def print_trades_info(holdings)
        return if holdings.size == 0
        printf("%20s\n", "TRADES")
        printf("%10s %19s %15s\n", '', 'Holding', 'Value')
        puts ''
        holdings.each do |symbol, holding|
          printf("%10s %19s %15s\n",
            '',
            symbol,
            commatize(holding[:value]))
        end
        puts ''
        puts '-' * 80
      end

      def print_summary(summary=nil)
        summary = get_summary() if summary.nil?
        if summary[:ignorable_total] > 0
          puts "Trading part: #{commatize(summary[:ignorable_total])}"
          puts "Portfolio part: #{commatize(summary[:full_total] - summary[:ignorable_total])}"
        end
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
        printf("%20s   %8s   %8s  %8s  %8s\n\n", "category", 'amount', 'actual %', 'desired %', 'delta')
        sorted_categories(summary).each do |category|
          if category == :TRADES
            print_trades_info(summary[:holdings_by_category][category])
            next
          end
          adjustment = summary[:adjustments_by_category][category]
          printf("%20s %12s % 8.02f%% % 8.02f%% %11s\n",
            category,
            commatize(adjustment[:total]),
            100 * adjustment[:actualFraction],
            100 * adjustment[:desiredFraction],
            commatize(adjustment[:delta]))
          puts ''

          holdings = summary[:holdings_by_category][category]
          if holdings.size == 0
            puts '-' * 80
            next
          end
          # pp holdings
          printf("%10s %19s %15s %20s %12s\n", "", *(%w/Holding Value Category-Desired% Delta/))
          holdings.each do |symbol, holding|
            printf("%10s %19s %15s % 19.02f%% %12s\n",
              '',
              symbol,
              commatize(holding[:value]),
              holding[:weight],
              commatize(holding[:delta]))
          end
          puts ''
          puts '-' * 80
        end
      end
          
    end
  end
end
