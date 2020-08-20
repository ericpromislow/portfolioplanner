
module PluginManager
  # Based on https://www.devco.net/archives/2009/12/01/ruby_plugin_architectures.php
  @plugins = {}

  def self.<<(klass)
    type = klass.name.split('::')[-1].to_sym
    raise("Plugin #{type} already loaded") if @plugins.include?(type)
    @plugins[type] = klass
  end

  def self.[](plugin)
    @plugins[plugin]
  end

  def self.each
    @plugins.each_key do |key|
      yield key, self[key]
    end
  end
end

Dir.glob(File.expand_path("../parsers/*.rb", __FILE__)).each do |path|
  require(path)
end
