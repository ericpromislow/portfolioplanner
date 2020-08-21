# shared stuff
#
require 'plugin_manager'

class BaseParser
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

  def self.inherited(klass)
    PluginManager << klass
  end
end
