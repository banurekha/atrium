require 'active_support/concern'
module Atrium::QueryParamMixin
  extend ActiveSupport::Concern

  included do
    attr_reader :saved_search_id
    attr_accessible :saved_search_id
    def saved_search_id=(value)
      @saved_search_id = value
      return @saved_search_id unless @saved_search_id.present?
      saved_search = nil
      begin
        saved_search = Atrium.saved_search_class.find(value)
      rescue ActiveRecord::RecordNotFound
        @saved_search_id = nil
      end
      formatted_query_params = {}
      if saved_search
        if saved_search.query_params.has_key?(:f)
          formatted_query_params[:f] = saved_search.query_params[:f]
        end
        if saved_search.query_params.has_key?(:q)
          formatted_query_params[:q] = saved_search.query_params[:q]
        end
      end
      self.filter_query_params = formatted_query_params
    end
    serialize :filter_query_params, Hash

    def filter_query_params
      begin
        super
      rescue ActiveRecord::SerializationTypeMismatch
        {}
      end
    end

    # This is a hopefully temporary work around that can be removed once all
    # atrium instances have a clean set of data.
    def read_attribute(attr_name)
      if attr_name.to_s == 'filter_query_params'
        begin
          super(attr_name)
        rescue ActiveRecord::SerializationTypeMismatch
          {}
        end
      else
        super
      end
    end
  end
end