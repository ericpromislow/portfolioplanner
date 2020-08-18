# shared stuff


def deep_symbolize_keys(obj)
  case obj
  when Hash
    h = {}
    obj.each {|k, v| h[k.to_s.to_sym] = deep_symbolize_keys(v)}
    return h
  when Array
    return obj.map {|v| deep_symbolize_keys(v)}
  else
    return obj
  end
end

def deep_stringify_symbols(obj)
  case obj
  when Hash
    h = {}
    obj.each do |k, v|
      if k.is_a?(Symbol)
        k = k.to_s
      end
      h[k] = deep_stringify_symbols(v)
    end
    return h
  when Array
    return obj.map {|v| deep_stringify_symbols(v)}
  when Symbol
    return obj.to_s
  else
    return obj
  end
end

def commatize(num)
  whole, part = ("%.2f" % num).split('.')
  "%s.%s" % [whole.reverse.scan(/\d{3}|.+/).join(",").reverse, part]
end

__END__

  def DesiredOutput
    entries = [
      {
        accountName: String,
        accountNum: String,
        statedTotal: Float,
        usrate: Float,
        accountLabel: String,
        cash: {
          currency: Float,  # Currency: CAD/USD
        },
        stated_totals: {
          currency: Float,  # Currency: CAD/USD
        }
        holdings: [
          {
            type: String, # "Mutual Funds"/"ETFs and ETNs"/Options/
            symbol: String,
            quantity: Float,
            price: Float,
            currency: Symbol,
            totalMarketValue: Float, # should be quantity * price
          } ],
      }
       ]
    entries
  end
