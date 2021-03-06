# require "netzke/grid_panel/grid_panel_js"
# require "netzke/grid_panel/grid_panel_api"
# require "netzke/grid_panel/grid_panel_columns"
# require "netzke/plugins/configuration_tool"
# require "data_accessor"

module Netzke::Component
  # == GridPanel
  # Ext.grid.EditorGridPanel + server-side code
  #
  # == Features:
  # * multi-line CRUD operations - get, post, delete, create
  # * (multe-record) editing and adding records through a form
  # * column resize, move and hide
  # * permissions
  # * sorting
  # * pagination
  # * filtering
  # * extended configurable search
  # * rows reordering (drag-n-drop)
  # * dynamic configuration of properties and columns
  #
  # == Class configuration
  # Configuration on this level is effective during the life-time of the application. They can be put into a .rb file
  # inside of config/initializers like this:
  # 
  #     Netzke::GridPanel.configure :column_filters_available, false
  #     Netzke::GridPanel.configure :default_config => {:ext_config => {:enable_config_tool => false}}
  # 
  # Most of these options directly influence the amount of JavaScript code that is generated for this component's class.
  # The less functionality is enabled, the less code is generated.
  # 
  # The following configuration options are available:
  # * <tt>:column_filters_available</tt> - (default is true) include code for the filters in the column's context menu
  # * <tt>:config_tool_available</tt> - (default is true) include code for the configuration tool that launches the configuration panel
  # * <tt>:edit_in_form_available</tt> - (defaults to true) include code for (multi-record) editing and adding records through a form
  # * <tt>:extended_search_available</tt> - (defaults to true) include code for extended configurable search
  # * <tt>:default_config</tt> - a hash of default configuration options for each instance of the GridPanel component.
  # See the "Instance configuration" section below.
  # 
  # == Instance configuration
  # The following config options are available:
  # * <tt>:model</tt> - name of the ActiveRecord model that provides data to this GridPanel.
  # * <tt>:strong_default_attrs</tt> - a hash of attributes to be merged atop of every created/updated record.
  # * <tt>:query</tt> - specifies how the data should be filtered.
  #   When it's a symbol, it's used as a scope name. 
  #   When it's a string, it's a SQL statement (passed directly to +where+). 
  #   When it's a hash, it's a conditions hash (passed directly to +where+). 
  #   When it's an array, it's expanded into SQL statement with arguments (passed directly to +where+), e.g.:
  #   
  #     :query => ["id > ?", 100])
  # 
  #   When it's a Proc, it's passed the model class, and is expected to return a ActiveRecord::Relation, e.g.:
  # 
  #     :query => { |klass| klass.where(:id.gt => 100).order(:created_at) }  
  #     
  # * <tt>:enable_column_filters</tt> - enable filters in column's context menu
  # * <tt>:enable_edit_in_form</tt> - provide buttons into the toolbar that activate editing/adding records via a form
  # * <tt>:enable_extended_search</tt> - provide a button into the toolbar that shows configurable search form
  # * <tt>:enable_context_menu</tt> - enable rows context menu
  # * <tt>:enable_rows_reordering</tt> - enable reordering of rows with drag-n-drop; underlying model (specified in <tt>:model</tt>) must implement "acts_as_list"-compatible functionality; defaults to <tt>false</tt>
  # * <tt>:enable_pagination</tt> - enable pagination; defaults to <tt>true</tt>
  # * <tt>:rows_per_page</tt> - number of rows per page (ignored when <tt>:enable_pagination</tt> is set to <tt>false</tt>)
  # * <tt>:load_inline_data</tt> - load initial data into the grid right after its instantiation (saves a request to server); defaults to <tt>true</tt>
  # * <tt>:mode</tt> - when set to <tt>:config</tt>, GridPanel loads in configuration mode
  # * <tt>:add/edit/multi_edit/search_form_config</tt> - additional configuration for add/edit/multi_edit/search form panel
  # * <tt>:add/edit/multi_edit_form_window_config</tt> - additional configuration for the window that wrapps up add/edit/multi_edit form panel
  # 
  # Additionally supports Netzke::Component::Base config options.
  # 
  # == Columns
  # Here's how the GridPanel decides which columns in which sequence and with which configuration to display.
  # First, the column configs are aquired from this GridPanel's persistent storage, as an array of hashes, each 
  # representing a column configuration, such as:
  #
  #   {:name => :created_at, :header => "Created", :tooltip => "When the record was created"}
  # 
  # This hash *overrides* (deep_merge) the hard-coded configuration, an example of which can be specifying 
  # columns for a GridPanel instance, e.g.:
  # 
  #   :columns => [{:name => :created_at, :sortable => false}]
  # 
  # ... which in its turn overrides the defaults provided by persistent storage managed by the AttributesConfigurator
  # that provides *model-level* (as opposed to a component-level) configuration of a database model 
  # (which is used by both grids and forms in Netzke).
  # And lastly, the defaults for AttributesConfigurator are calculated from the database model itself (extended by Netzke).
  # For example, in the model you can specify virtual attributes and their types that will be picked up by Netzke, the default
  # order of columns, or excluded columns. For details see <tt>Netzke::ActiveRecord::Attributes</tt>.
  # 
  # The columns are displayed in the order specified by what's found first in the following sequence:
  #   GridPanel instance's persistent storage
  #   hardcoded config
  #   AttributesConfigurator persistent storage
  #   netzke_expose_attributes in the database model
  #   database columns + (eventually) virtual attributes specified with netzke_attribute
  class GridPanel < Base
    # Class-level configuration. This options directly influence the amount of generated
    # javascript code for this component's class. For example, if you don't want filters for the grid, 
    # set :column_filters_available to false, and the javascript for the filters won't be included at all.
    def self.config
      # Btw, this method must be on top of the class, because the code below can be using it at the very moment of defining the class.
      
      set_default_config({
        
        :column_filters_available     => true,
        :config_tool_available        => true,
        :edit_in_form_available       => true,
        :extended_search_available    => true,
        :rows_reordering_available    => true,
        
        :default_config => {
          :enable_edit_in_form    => true,
          :enable_extended_search => true,
          :enable_column_filters  => true,
          :load_inline_data       => true,
          :enable_context_menu    => true,
          :enable_rows_reordering => false, # column drag n drop
          :enable_pagination      => true,
          :rows_per_page          => 25,
          :tools                  => %w{ refresh },
          
          :mode                   => :normal, # when set to :config, :configuration button is enabled
          :persistent_config      => true
          
        }
      })
    end
    
    # Be specific about inclusion, because base class also may have similar modules
    include self::Javascript
    include self::Services
    include self::Columns
    
    include Netzke::DataAccessor

    # TODO: 2010-09-14
    def self.enforce_config_consistency
      # config[:default_config][:ext_config][:enable_edit_in_form]    &&= config[:edit_in_form_available]
      # config[:default_config][:ext_config][:enable_extended_search] &&= config[:extended_search_available]
      # config[:default_config][:ext_config][:enable_rows_reordering] &&= config[:rows_reordering_available]
    end
    
    # def initialize(*args)
    #   # Deprecations
    #   config[:scopes] && ActiveSupport::Deprecation.warn(":scopes option is not effective any longer for GridPanel. Use :scope instead.")
    #   
    #   super(*args)
    # end

    # Include extra javascript that we depend on
    def self.include_js
      res = ["#{File.dirname(__FILE__)}/grid_panel/javascripts/pre.js"]
      
      # Optional edit in form functionality
      res << "#{File.dirname(__FILE__)}/grid_panel/javascripts/edit_in_form.js" if config[:edit_in_form_available]
      
      # Optional extended search functionality
      res << "#{File.dirname(__FILE__)}/grid_panel/javascripts/advanced_search.js" if config[:extended_search_available]
      
      ext_examples = Netzke::Component::Base.config[:ext_location].join("examples")
      
      # Checkcolumn
      res << ext_examples.join("ux/CheckColumn.js")
      
      # Filters
      if config[:column_filters_available]
        res << ext_examples + "ux/gridfilters/menu/ListMenu.js"
        res << ext_examples + "ux/gridfilters/menu/RangeMenu.js"
        res << ext_examples + "ux/gridfilters/GridFilters.js"
      
        %w{Boolean Date List Numeric String}.unshift("").each do |f|
          res << ext_examples + "ux/gridfilters/filter/#{f}Filter.js"
        end
      end
      
      # DD
      if config[:rows_reordering_available]
        res << "#{File.dirname(__FILE__)}/grid_panel/javascripts/rows-dd.js"
      end

      res
    end
    
    

    # Fields to be displayed in the "General" tab of the configuration panel
    def self.property_fields
      [
        # {:name => :ext_config__title,               :attr_type => :string},
        # {:name => :ext_config__header,              :attr_type => :boolean, :default => true},
        # {:name => :ext_config__enable_context_menu, :attr_type => :boolean, :default => true},
        # {:name => :ext_config__enable_pagination,   :attr_type => :boolean, :default => true},
        # {:name => :ext_config__rows_per_page,       :attr_type => :integer},
        # {:name => :ext_config__prohibit_create,     :attr_type => :boolean},
        # {:name => :ext_config__prohibit_update,     :attr_type => :boolean},
        # {:name => :ext_config__prohibit_delete,     :attr_type => :boolean},
        # {:name => :ext_config__prohibit_read,       :attr_type => :boolean}
      ]
    end
    
    def default_bbar
      res = %w{ add edit apply del }.map(&:to_sym).map(&:ext_action)
      res << "-" << :add_in_form.ext_action << :edit_in_form.ext_action if config[:enable_edit_in_form]
      res << "-" << :search.ext_action if config[:enable_extended_search]
      res
    end
    
    def default_context_menu
      res = %w{ edit del }.map(&:to_sym).map(&:ext_action)
      res << "-" << :edit_in_form.ext_action if config[:enable_edit_in_form]
      res
    end
    
    def configuration_components
      res = []
      res << {
        :persistent_config => true,
        :name              => 'columns',
        :class_name        => "FieldsConfigurator",
        :active            => true,
        :owner             => self
      }
      res << {
        :name               => 'general',
        :class_name  => "PropertyEditor",
        :component             => self,
        :title => false
      }
      res
    end

    def actions
      # Defaults
      actions = {                                     
        :add          => {:text => 'Add',          :disabled => config[:prohibit_create]},
        :edit         => {:text => 'Edit',         :disabled => true},
        :del          => {:text => 'Delete',       :disabled => true},
        :apply        => {:text => 'Apply',        :disabled => config[:prohibit_update] && config[:prohibit_create]},
        :add_in_form  => {:text => 'Add in form',  :disabled => !config[:enable_edit_in_form]},
        :edit_in_form => {:text => 'Edit in form', :disabled => true},
        :search       => {:text => 'Search',       :disabled => !config[:enable_extended_search], :checked => true}
      }
      
      if Netzke::Component::Base.config[:with_icons]
        icons_uri = Netzke::Component::Base.config[:icons_uri] + "/"
        actions.deep_merge!(
          :add => {:icon => icons_uri + "add.png"},
          :edit => {:icon => icons_uri + "table_edit.png"},
          :del => {:icon => icons_uri + "table_row_delete.png"},
          :apply => {:icon => icons_uri + "tick.png"},
          :add_in_form => {:icon => icons_uri + "application_form_add.png"},
          :edit_in_form => {:icon => icons_uri + "application_form_edit.png"},
          :search => {:icon => icons_uri + "find.png"}
        )
      end
      
      actions
    end

    def components
      @_components ||= begin
        res = {}
        
        # Edit in form
        res.merge!({
          :add_form => {
            :lazy_loading => true,
            :class_name => "Component::GridPanel::RecordFormWindow",
            :title => "Add #{data_class.table_name.singularize.humanize}",
            :button_align => "right",
            :items => [{
              :class_name => "Component::FormPanel",
              :model => config[:model],
              :items => default_fields_for_forms,
              :persistent_config => config[:persistent_config],
              :strong_default_attrs => config[:strong_default_attrs],
              :border => true,
              :bbar => false,
              :header => false,
              :mode => config[:mode],
              :record => data_class.new
            }.deep_merge(config[:add_form_config] || {})]
          }.deep_merge(config[:add_form_window_config] || {}),
        
          :edit_form => {
            :lazy_loading => true,
            :class_name => "Component::GridPanel::RecordFormWindow",
            :title => "Edit #{data_class.table_name.singularize.humanize}",
            :button_align => "right",
            :items => [{
              :class_name => "Component::FormPanel",
              :model => config[:model],
              :fields => default_fields_for_forms,
              :persistent_config => config[:persistent_config],
              :bbar => false,
              :header => false,
              :mode => config[:mode]
              # :record_id gets assigned by load_component_with_cache at the moment of loading
            }.deep_merge(config[:edit_form_config] || {})]
          }.deep_merge(config[:edit_form_window_config] || {}),
        
          :multi_edit_form => {
            :lazy_loading => true,
            :class_name => "Component::GridPanel::RecordFormWindow",
            :title => "Edit #{data_class.table_name.humanize}",
            :button_align => "right",
            :items => [{
              :class_name => "Component::GridPanel::MultiEditForm",
              :model => config[:model],
              :fields => default_fields_for_forms,
              :persistent_config => config[:persistent_config],
              :bbar => false,
              :header => false,
              :mode => config[:mode]
            }.deep_merge(config[:multi_edit_form_config] || {})]
          }.deep_merge(config[:multi_edit_form_window_config] || {})
        }) if config[:enable_edit_in_form]
      
        # Extended search
        res.merge!(:search_panel => search_panel.merge(:lazy_loading => true).deep_merge(config[:search_form_config] || {})) if config[:enable_extended_search]
      
        res
      end
    end
    
    def search_panel
      {
        :class_name => "Component::SearchPanel",
        # :fields => default_fields_for_forms,
        :search_class_name => config[:model],
        :persistent_config => config[:persistent_config],
        :header => false, 
        :bbar => false, 
        :mode => config[:mode]
      }
    end

    include ::Netzke::Plugins::ConfigurationTool if config[:config_tool_available] # it will load ConfigurationPanel into a modal window
 
  end
end