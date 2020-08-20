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

end
