require 'active_record'
#require 'searchlogic'
require 'meta_where'
require 'will_paginate'

module Netzke::Component
  class GridPanel < Base
    module Services
      extend ActiveSupport::Concern
      
      included do
      
        endpoint :get_data do |*args|
          params = args.first || {} # params are optional
          if !config[:prohibit_read]
            records = get_records(params)
            {:data => records.map{|r| r.to_array(columns)}, :total => config[:enable_pagination] && records.total_entries}
          else
            flash :error => "You don't have permissions to read data"
            {:feedback => @flash}
          end
        end

        endpoint :post_data do |params|
          mod_records = {}
          [:create, :update].each do |operation|
            data = ActiveSupport::JSON.decode(params["#{operation}d_records"]) if params["#{operation}d_records"]
            if !data.nil? && !data.empty? # data may be nil for one of the operations
              mod_records[operation] = process_data(data, operation)
              mod_records[operation] = nil if mod_records[operation].empty?
            end
          end
        
          on_data_changed
        
          {
            :update_new_records => mod_records[:create], 
            :update_mod_records => mod_records[:update] || {},
            :feedback => @flash
          }
        end

        endpoint :delete_data do |params|
          if !config[:prohibit_delete]
            record_ids = ActiveSupport::JSON.decode(params[:records])
            data_class.destroy(record_ids)
            on_data_changed
            {:feedback => "Deleted #{record_ids.size} record(s)", :load_store_data => get_data}
          else
            {:feedback => "You don't have permissions to delete data"}
          end
        end

        endpoint :resize_column do |params|
          raise "Called api_resize_column while not configured to do so" if config[:enable_column_resize] == false
          columns[normalize_index(params[:index].to_i)][:width] = params[:size].to_i
          save_columns!
          {}
        end

        endpoint :move_column do |params|
          raise "Called api_move_column while not configured to do so" if config[:enable_column_move] == false
          remove_from = normalize_index(params[:old_index].to_i)
          insert_to = normalize_index(params[:new_index].to_i)
          column_to_move = columns.delete_at(remove_from)
          columns.insert(insert_to, column_to_move)
          save_columns!

          # reorder the columns on the client side (still not sure if it's not an overkill)
          # {:reorder_columns => columns.map(&:name)} # Well, I think it IS an overkill - commented out 
          # until proven to be necessary
          {}
        end

        endpoint :hide_column do |params|
          raise "Called api_hide_column while not configured to do so" if config[:enable_column_hide] == false
          columns[normalize_index(params[:index].to_i)][:hidden] = params[:hidden].to_b
          save_columns!
          {}
        end

        # Returns choices for a column
        endpoint :get_combobox_options do |params|
          query = params[:query]

          column = columns.detect{ |c| c[:name] == params[:column] }
          scope = column.to_options[:scope]
          query = params[:query]

          {:data => combobox_options_for_column(column, :query => query, :scope => scope, :record_id => params[:id])}
        end

        endpoint :move_rows do |params|
          if defined?(ActsAsList) && data_class.ancestors.include?(ActsAsList::InstanceMethods)
            ids = JSON.parse(params[:ids]).reverse
            ids.each_with_index do |id, i|
              r = data_class.find(id)
              r.insert_at(params[:new_index].to_i + i + 1)
            end
            on_data_changed
          else
            raise RuntimeError, "Data class should 'acts_as_list' to support moving rows"
          end
          {}
        end
        
      end
      #
      # Some components' overridden API 
      # 
    
      ## Edit in form specific API
      def add_form__item__netzke_submit(params)
        res = component_instance(:add_form__item).netzke_submit(params)
      
        if res[:set_form_values]
          # successful creation
          on_data_changed
          res[:set_form_values] = nil
        end
        res.to_nifty_json
      end

      def edit_form__item__netzke_submit(params)
        res = component_instance(:edit_form__item).netzke_submit(params)

        if res[:set_form_values]
          on_data_changed
          res[:set_form_values] = nil
        end
      
        res.to_nifty_json
      end

      def multi_edit_form__item__netzke_submit(params)
        ids = ActiveSupport::JSON.decode(params.delete(:ids))
        data = ids.collect{ |id| ActiveSupport::JSON.decode(params[:data]).merge("id" => id) }
        
        mod_records_count = process_data(data, :update).count
        
        # remove duplicated flash messages
        @flash = @flash.inject([]){ |r,hsh| r.include?(hsh) ? r : r.push(hsh) }
        
        if mod_records_count > 0
          on_data_changed
          flash :notice => "Updated #{mod_records_count} records."
          {:set_result => "ok", :feedback => @flash}.to_nifty_json
        else
          {:feedback => @flash}.to_nifty_json
        end
      end
      
      # When providing the edit_form component, fill in the form with the requested record
      def load_component_with_cache(params)
        components[:edit_form][:items].first.merge!(:record_id => params[:record_id].to_i) if params[:name] == 'edit_form'
        super
      end
      
      protected
        
        def get_records(params)
          
          # Restore params from component_session if requested
          if params[:with_last_params]
            params = component_session[:last_params]
          else
            # remember the last params
            component_session[:last_params] = params
          end
      
          # build initial relation based on passed params
          relation = get_relation(params)
      
          # apply sorting if needed
          if params[:sort]
            assoc, method = params[:sort].split('__')

						# Only try to sort if the model reponds to :assoc. If it does, it is probably a column or an association
						if data_class.respond_to? assoc.to_sym
	            dir = params[:dir].downcase
	            relation = if method.nil?
	              relation.order(assoc.to_sym.send(dir))
	            else
	              relation.order(assoc.tableize.to_sym => method.to_sym.send(dir)).joins(assoc.to_sym)
	            end
						end

          end
          
          # apply pagination if needed
          if config[:enable_pagination]
            per_page = config[:rows_per_page]
            page = params[:limit] ? params[:start].to_i/params[:limit].to_i + 1 : 1
            relation.paginate(:per_page => per_page, :page => page)
          else
            relation.all
          end
        end
    
        # Returns ActiveRecord::Relation instance encapsulating all the necessary conditions
        def get_relation(params)
          # make params coming from Ext grid filters understandable by meta_where
          # search_params = normalize_params(params)
          conditions = params[:filter] && convert_filters(params[:filter]) || {}
          
          # merge with conditions coming from the config
          # search_params[:conditions].deep_merge!(config[:conditions] || {})

          # merge with extra conditions (in MetaWhere format, come from the extended search form)
          conditions.deep_merge!(
            normalize_extra_conditions(ActiveSupport::JSON.decode(params[:extra_conditions]))
          ) if params[:extra_conditions]
                                   
          relation = data_class.where(conditions)
          
          relation = relation.extend_with(config[:scope]) if config[:scope]
          
          relation
        end
      
        # Override this method to react on each operation that caused changing of data
        def on_data_changed; end
    
        # Given an index of a column among enabled (non-excluded) columns, provides the index (position) in the table
        def normalize_index(index)
          norm_index = 0
          index.times do
            while true do
              norm_index += 1 
              break unless columns[norm_index][:included] == false
            end
          end
          norm_index
        end

        # Params: 
        # <tt>:operation</tt>: :update or :create
        def process_data(data, operation)
          success = true
          # mod_record_ids = []
          mod_records = {}
          if !config[:"prohibit_#{operation}"]
            modified_records = 0
            data.each do |record_hash|
              id = record_hash.delete('id')
              record = operation == :create ? data_class.new : data_class.find(id)
              success = true

              # merge with strong default attirbutes
              record_hash.merge!(config[:strong_default_attrs]) if config[:strong_default_attrs]

              # process all attirubutes for this record
              record_hash.each_pair do |k,v|
                begin
                  record.send("#{k}=",v)
                rescue ArgumentError => exc
                  flash :error => exc.message
                  success = false
                  break
                end
              end
        
              # try to save
              # modified_records += 1 if success && record.save
              mod_records[id] = record.to_array(columns) if success && record.save
              # mod_record_ids << id if success && record.save

              # flash eventual errors
              if !record.errors.empty?
                success = false
                record.errors.each_full do |msg|
                  flash :error => msg
                end
              end
            end
            # flash :notice => "#{operation.to_s.capitalize}d #{modified_records} record(s)"
          else
            success = false
            flash :error => "You don't have permissions to #{operation} data"
          end
          mod_records
        end

        # Converts Ext.ux.grid.GridFilters filters to searchlogic conditions, e.g.
        #     {"0" => {
        #       "data" => {
        #         "type" => "numeric", 
        #         "comparison" => "gt", 
        #         "value" => 10 }, 
        #       "field" => "id"
        #     }, 
        #     "1" => {
        #       "data" => {
        #         "type" => "string",
        #         "value" => "pizza"
        #       },
        #       "field" => "food_name"
        #     }}
        #     
        #      => 
        #             
        #  metawhere:   :id.gt => 100, :food_name.matches => '%pizza%'
        def convert_filters(column_filter)
          res = {}
          column_filter.each_pair do |k,v|
            field = v["field"].dup.to_sym
            
            value = v["data"]["value"]
            case v["data"]["type"]
            when "string"
              field = field.send :matches
              value = "%#{value}%"
            when "numeric", "date"
              field = field.send :"#{v['data']['comparison']}"
            end                      
            res.merge!({field => value})
          end
          res
        end

        def normalize_extra_conditions(conditions)
          conditions.deep_convert_keys{|k| get_key(k)}
        end

        def get_key(k)
          k.gsub("__", "").to_sym          
        end

        # make params understandable to searchlogic
        def normalize_params(params)
          # filters
          conditions = params[:filter] && convert_filters(params[:filter]) || {}
        
          Rails.logger.debug "***** conditions: #{conditions.inspect}\n"
        
          # normalized_conditions = {}
          # conditions && conditions.each_pair do |k, v|
          #   normalized_conditions.merge!(get_key(k) => v)
          # end
          # 
          # {:conditions => normalized_conditions}
          {:conditions => conditions}
        end
    
        # def check_for_positive_result(res)
        #   if res[:set_form_values]
        #     # successful creation
        #     res[:set_form_values] = nil
        #     res.merge!({
        #       :parent => {:on_successfull_edit => true}
        #     })
        #     true
        #   else
        #     false
        #   end
        # end

    end
  end
end
