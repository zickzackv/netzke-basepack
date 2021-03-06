module Netzke::Component
  # TabPanel
  # 
  # Features (TODO):
  # * Dynamically loads components for the tabs that get activated for the first time
  # * Is loaded along with the active component - saves a request to the server
  # * Provides the method markTabsOutdated to mark all inactive tabs as 'outdated', and calls "update" method on components in tabs when they get activated
  #
  # TODO:
  # * Stores the last active tab in persistent_config
  # * Introduce a second or two delay before informing the server about a tab switched
  # 
  class TabPanel < Base
    def self.js_base_class
      "Ext.TabPanel"
    end

    # def config
    #   {
    #     :items => [{:class_name => "Component::GridPanel", :title => "Blah1", :model => "User"}, {:title => "Blah2", :html => "Testik"}]
    #   }.deep_merge(super)
    # end
  end
end