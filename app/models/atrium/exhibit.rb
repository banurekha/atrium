class Atrium::Exhibit < ActiveRecord::Base
  has_many :showcases, :class_name=>'Atrium::Showcase', :foreign_key=>"atrium_exhibit_id", :order=>'set_number ASC', :dependent => :destroy
  has_many :search_facets, :class_name=>'Atrium::Search::Facet', :foreign_key=>"atrium_exhibit_id" , :dependent => :destroy

  accepts_nested_attributes_for :showcases, :allow_destroy=>true
  accepts_nested_attributes_for :search_facets, :allow_destroy=>true

  set_table_name :atrium_exhibits

  serialize :filter_query_params

  def title
    title = super
    title.nil? ? "" : title
  end
end
