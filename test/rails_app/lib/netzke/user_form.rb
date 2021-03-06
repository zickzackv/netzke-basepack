module Netzke
  class UserForm < Component::FormPanel
    def config
      {
        :model => 'User',
        :title => 'Users',
        :record_id => User.first.id,
        :items => [
          {:xtype => 'fieldset', :checkbox_toggle => false, :title => "Basic Info", :items => [:first_name, {:name => :last_name}]},
          {:xtype => 'fieldset', :checkbox_toggle => false, :title => "Timestamps", :items => [{:name => :created_at}, {:name => :updated_at}]},
          :role__name,
          # {:xtype => 'tabpanel', :active_tab => 0, :items => [{:class_name => "UserGrid"}, {:title => "Tab Two"}]}
        ]
      }.deep_merge super
    end
    
  end
end