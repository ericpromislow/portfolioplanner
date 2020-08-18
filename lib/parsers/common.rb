# shared stuff

module Parsers
  module Common

    class Analyzer
      def createEntry
        return {
          accountName: "",
          accountNum: "",
          usrate: 0,
          accountLabel: "",
          cash: {},
          stated_totals: {},
          stated_investments: {},
          holdings: [],
        }
      end
    end

  end

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
end
