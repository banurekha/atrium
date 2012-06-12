class Atrium::Showcase::FacetSelection < ActiveRecord::Base
  self.table_name = 'atrium_showcase_facet_selections'

  belongs_to :showcase, :class_name => 'Atrium::Showcase', :foreign_key => 'atrium_showcase_id'

  validates_presence_of :atrium_showcase_id, :value, :solr_facet_name

end
