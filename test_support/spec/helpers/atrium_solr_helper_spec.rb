require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

Blacklight::SolrHelper.stubs(:class_inheritable_accessor)

describe Atrium::SolrHelper do

  before(:each) do
    @collection = Atrium::Collection.new
    @collection.save
  end

  after(:each) do
    begin
      @collection.delete
    rescue
    end
    begin
      @exhibit.delete
    rescue
    end
  end

  describe "initialize_collection" do
    it "atrium_collection should be nil if both :id (if atrium_collections controller) and :collection_id not in params" do
      helper.stubs(:params).returns({:id=>"test_id"})
      helper.initialize_collection
      helper.atrium_collection.should == nil
      helper.stubs(:params).returns({:controller=>"atrium_collections",:collection_id=>"test_id"})
      helper.atrium_collection.should == nil
    end

    it "should raise an exception if the collection_id passed in does not exist" do
      helper.expects(:params).returns({:id=>"test_id",:controller=>"atrium_collections"}).at_least_once
      #these only get called once if an collection is found
      helper.expects(:build_lucene_query).returns("_query_:id\:test_id")
      helper.expects(:get_search_results)
      @collection.save!
      logger.expects(:error).twice
      helper.initialize_collection
      #check valid case as well
      helper.expects(:params).returns({:id=>@collection.id,:controller=>"atrium_collections"}).at_least_once
      helper.initialize_collection
    end

    it "should configure params correctly if facet selected and facet in filter" do
      helper.stubs(:params).returns({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}})
      @collection.filter_query_params = {:q=>"testing",:f=>{"season"=>["spring"]}}
      Atrium::Collection.expects(:find).with("test_id").returns(@collection)
      helper.expects(:solr_search_params).with(@collection.filter_query_params).returns(:q=>"testing",:fq=>["{!raw f=season_facet}Spring"]).at_least_once
      helper.expects(:solr_search_params).with({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}}).returns(:fq=>["{!raw f=continent}North America"])
      #it will combine param facet and filter facet into extra params so that the params facets are not overwritten when the filter facet is applied
      extra_params = {:q=>"testing", :fq=>["{!raw f=continent}North America","{!raw f=season_facet}Spring"]}
      helper.expects(:get_search_results).with({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}},extra_params)
      helper.initialize_collection
    end

    it "should configure params correctly if facet selected and no facet in filter" do
      helper.stubs(:params).returns({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}})
      @collection.filter_query_params = {:q=>"testing"}
      Atrium::Collection.expects(:find).with("test_id").returns(@collection)
      helper.expects(:solr_search_params).with(@collection.filter_query_params).returns(:q=>"testing").once
      #it will combine param facet and filter facet into extra params so that the params facets are not overwritten when the filter facet is applied
      extra_params = {:q=>"testing"}
      helper.expects(:get_search_results).with({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}},extra_params)
      helper.initialize_collection
    end

    it "should configure params correctly if facet selected with same facet in filter" do
      helper.stubs(:params).returns({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}})
      @collection.filter_query_params = {:q=>"testing",:f=>{"continent"=>["North America"]}}
      Atrium::Collection.expects(:find).with("test_id").returns(@collection)
      helper.expects(:solr_search_params).with(@collection.filter_query_params).returns(:q=>"testing",:fq=>["{!raw f=continent}North America"]).once
      helper.expects(:solr_search_params).with({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}}).returns(:fq=>["{!raw f=continent}North America"])
      #it will combine param facet and filter facet into extra params so that the params facets are not overwritten when the filter facet is applied
      extra_params = {:q=>"testing", :fq=>["{!raw f=continent}North America"]}
      helper.expects(:get_search_results).with({:collection_id=>"test_id",:f=>{"continent"=>["North America"]}},extra_params)
      helper.initialize_collection
    end
  end

  describe "get_exhibit_navigation_data" do
    it "if atrium collection still nil after calling initialize collection than should return empty array" do
      helper.expects(:params).returns({:collection_id=>"test_id"}).at_least_once
      Atrium::Collection.expects(:find).with("test_id").returns(nil)
      helper.expects(:get_browse_level_data).times(0)
      helper.get_exhibit_navigation_data.should == []
    end

    it "if no atrium collection exhibits it should return an empty array" do
      collection = mock()
      collection.stubs(:exhibits).returns([])
      helper.stubs(:atrium_collection).returns(collection)
      helper.stubs(:check_for_scope).returns(false)
      helper.get_exhibit_navigation_data.should == []
    end

    it "if atrium collection is not nil and has exhibits it should call get browse level data for each browse set" do
      collection = Atrium::Collection.new
      collection.save
      collection.stubs(:exhibits).returns([])
      helper.stubs(:atrium_collection).returns(collection)
      exhibit1 = Atrium::Exhibit.new({:atrium_collection_id=>collection.id,:set_number=>1})
      exhibit1.save
      exhibit2 = Atrium::Exhibit.new({:atrium_collection_id=>collection.id,:set_number=>2})
      exhibit2.save
      browse_level1 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>exhibit1.id,:solr_facet_name=>"my_facet",:label=>"my_label"})
      browse_level2 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>exhibit2.id,:solr_facet_name=>"my_facet2",:label=>"my_label2"})
      browse_level3 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>exhibit2.id,:solr_facet_name=>"my_facet3",:label=>"my_label3"})
      exhibit1.stubs(:browse_levels).returns([browse_level1])
      exhibit2.stubs(:browse_levels).returns([browse_level2,browse_level3])
      collection.expects(:exhibits).returns([exhibit1,exhibit2]).at_least_once
      browse_response = mock()
      helper.stubs(:browse_response).returns(browse_response)
      extra_con_params = mock()
      helper.stubs(:current_extra_controller_params).returns(extra_con_params)
      updated_browse_level1 = browse_level1.clone
      updated_browse_level1.expects(:values).returns(["test1","test2"])
      updated_browse_level1.expects(:selected).returns("test1")
      updated_browse_level2 = browse_level2.clone
      updated_browse_level2.expects(:values).returns(["test3","test4"])
      helper.expects(:get_browse_level_data).with(collection,exhibit1,[browse_level1],browse_response,extra_con_params,true).returns([updated_browse_level1])
      helper.expects(:get_browse_level_data).with(collection,exhibit2,[browse_level2,browse_level3],browse_response,extra_con_params,true).returns([updated_browse_level2,browse_level3])
      #check that the array returned is flattened appropriately on concat
      browse_data = helper.get_exhibit_navigation_data
      browse_data.size.should == 2
      #order is important here for both browse sets and esp. nested levels
      browse_data.first.should == exhibit1
      browse_data.second.should == exhibit2
      browse_data.first.browse_levels.first.values.should == ["test1","test2"]
      browse_data.first.browse_levels.first.selected.should == "test1"
      browse_data.second.browse_levels.first.values.should == ["test3","test4"]
      browse_data.second.browse_levels.first.selected.should == nil
      #for the other browse level of the second browse set values should be empty since nothing selected in parent
      browse_data.second.browse_levels.second.values.should == []
    end
  end

  describe "get_browse_level_data" do
    it "should return an array of exhibit objects with browse levels objects sorted by level number if any defined" do
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      @exhibit2 = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>2})
      @exhibit2.save
      helper.expects(:facet_field_labels).returns("my_label").times(3)
      #label will be nil
      browse_level1 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet", :level_number=>1})
      browse_level1.save
      browse_level2 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet2", :level_number=>2})
      browse_level2.save
      @exhibit.stubs(:browse_levels).returns([browse_level1,browse_level2])
      browse_level3 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit2.id,:solr_facet_name=>"my_facet2", :level_number=>1})
      browse_level3.save
      browse_level4 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit2.id,:solr_facet_name=>"my_facet3", :level_number=>2})
      browse_level4.save
      @exhibit2.stubs(:browse_levels).returns([browse_level3,browse_level4])
      @collection.expects(:exhibits).returns([@exhibit,@exhibit2]).at_least_once
      helper.expects(:atrium_collection).returns(@collection).at_least_once
      
      browse_response = mock()
      facet1 = mock()
      facet2 = mock()
      facet3 = mock()
      item1 = mock()
      item2 = mock()
      item3 = mock()
      item4 = mock()
      item5 = mock()
      
      item1.expects(:value).returns("val1").at_least_once
      item2.expects(:value).returns("val2").at_least_once
      item3.expects(:value).returns("val3").at_least_once
      item4.expects(:value).returns("val4").at_least_once
      item5.expects(:value).returns("val5").at_least_once

      facet1.expects(:items).returns([item1,item2]).at_least_once
      facet1.expects(:name).returns("my_facet").at_least_once
      facet2.expects(:items).returns([item3,item4,item5]).at_least_once
      facet2.expects(:name).returns("my_facet2").at_least_once
      browse_response.expects(:facets).returns([facet1,facet2,facet3]).at_least_once
      helper.stubs(:browse_response).returns(browse_response)
      helper.expects(:facet_in_params?).returns(false).at_least_once
      #this will make it have something be selected
      helper.expects(:facet_in_params?).with('my_facet','val2').returns(true)
      helper.stubs(:get_search_results).returns([browse_response,mock()])

      browse_data = helper.get_exhibit_navigation_data
      browse_data.size.should == 2
      browse_data.first.should == @exhibit
      browse_data.second.should == @exhibit2

      browse_data.first.browse_levels.first.should == browse_level1
      browse_data.first.browse_levels.second.should == browse_level2
      browse_data.second.browse_levels.first.should == browse_level3
      browse_data.second.browse_levels.second.should == browse_level4

      browse_data.first.browse_levels.first.values.should == ["val1","val2"]
      browse_data.first.browse_levels.second.values.should == ["val3","val4","val5"]
      browse_data.second.browse_levels.first.values.should == ["val3","val4","val5"]
      browse_data.second.browse_levels.second.values.should == []

      browse_data.first.browse_levels.first.selected.should == "val2"
      browse_data.first.browse_levels.second.selected.should == nil
      browse_data.second.browse_levels.first.selected.should == nil
      browse_data.second.browse_levels.second.selected.should == nil
    end

    it "should use the blacklight facet field label if no label defined in a browse level" do
      #must have a browse set and collection not nil
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      #add a browse level with label nil
      browse_level = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:level_number=>1})
      @exhibit.expects(:browse_levels).returns([browse_level]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)
      helper.expects(:facet_field_labels).returns({"my_facet"=>"my_label"}).times(2)
      #response must have facet for this level
      response = mock()
      facet = mock()
      facet.expects(:name).returns("my_facet").times(4)
      #no items in facet to skip calling get_browse_set_data
      facet.expects(:items).returns([]).twice
      response.expects(:facets).returns([facet]).times(4)
      helper.stubs(:browse_response).returns(response)
      helper.stubs(:get_search_results).returns([response,mock()])
      browse_data = helper.get_exhibit_navigation_data
      browse_data.first.browse_levels.first.label.should == "my_label"
      #check if label is blank instead
      browse_level.label = ""
      browse_data = helper.get_exhibit_navigation_data
      browse_data.first.browse_levels.first.label.should == "my_label"
    end

    it "should use the label in a browse level if defined" do
      helper.expects(:facet_field_labels).returns("my_label").times(0)
      #must have a browse set and collection not nil
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      browse_level = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:label=>"my_label_2"})
      @exhibit.expects(:browse_levels).returns([browse_level]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)
      response = mock()
      facet = mock()
      facet.expects(:items).returns([]).at_least_once
      facet.expects(:name).returns("my_facet").at_least_once
      response.expects(:facets).returns([facet]).at_least_once
      helper.stubs(:browse_response).returns(response)
      helper.stubs(:get_search_results).returns([response,mock()])
      helper.get_exhibit_navigation_data.first.browse_levels.first.label.should == "my_label_2"
    end

    it "if no f param is defined it should set the response without f param to be response" do
      #if they are the same then response.facets should be called twice
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      browse_level = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:label=>"my_label"})
      @exhibit.expects(:browse_levels).returns([browse_level]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)
      response = mock()
      facet = mock()
      facet.expects(:name).returns("other_facet").at_least_once
      #it will call this twice if response is same for without f param
      response.expects(:facets).returns([facet]).twice
      helper.expects(:browse_response).returns(response)
      helper.stubs(:get_search_results).returns([response,mock()])
      helper.get_exhibit_navigation_data
    end

    it "if multiple browse levels defined and f defined for anything but top level it should only have values set for the top level" do
      #must have a browse set and collection not nil
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      #add a browse level with label nil
      browse_level1 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:level_number=>1})
      browse_level2 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet2",:level_number=>2})
      @exhibit.expects(:browse_levels).returns([browse_level1,browse_level2]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)
      
      #put something in params different from our facet, use facet at second level but should be ignored
      helper.expects(:params).returns({:f=>{"my_facet2"=>["val3"]}}).at_least_once
      facet1 = mock()
      facet1.expects(:name).returns("my_facet").at_least_once
      item1 = mock()
      item1.expects(:value).returns("val1").at_least_once
      item2 = mock()
      item2.expects(:value).returns("val2").at_least_once
      item3 = mock()
      item3.stubs(:value).returns("val3")
      facet1.expects(:items).returns([item1,item2]).at_least_once
      facet2 = mock()
      facet2.expects(:name).returns("my_facet2").at_least_once
      #stub so it can be called but not necessarily expected
      facet2.stubs(:items).returns([item3])
      response = mock()
      response.expects(:facets).returns([facet2,facet1]).at_least_once
      helper.expects(:browse_response).returns(response)
      helper.expects(:facet_field_labels).returns("my_label")
      helper.expects(:get_search_results).returns([response,mock()])
      browse_data = helper.get_exhibit_navigation_data
      browse_data.first.browse_levels.first.values.should == ["val1","val2"]
      browse_data.first.browse_levels.first.selected.should == nil
      browse_data.first.browse_levels.second.values.should == []
      browse_data.first.browse_levels.second.selected.should == nil
    end

    it "if 3 browse levels defined and two items selected in each browse level then it should return 2 browse levels with values" do
      #must have a browse set and collection not nil
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      #add a browse level with label nil
      browse_level1 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:level_number=>1})
      browse_level2 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet2",:level_number=>2})
      browse_level3 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet3",:level_number=>3})
      @exhibit.expects(:browse_levels).returns([browse_level1,browse_level2,browse_level3]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)
      helper.expects(:params).returns({:collection_id=>@collection.id,:f=>{"my_facet"=>["my_val2"],"my_facet2"=>"my_val3"}}).at_least_once
      helper.expects(:atrium_collection).returns(@collection)
      facet = mock()
      facet.expects(:name).returns("my_facet").at_least_once
      item = mock()
      item.expects(:value).returns("my_val").at_least_once
      item2 = mock()
      item2.expects(:value).returns("my_val2").at_least_once
      facet.expects(:items).returns([item,item2]).at_least_once

      facet2 = mock()
      facet2.expects(:name).returns("my_facet2").at_least_once
      item3 = mock()
      item3.expects(:value).returns("my_val3").at_least_once
      item4 = mock()
      item4.expects(:value).returns("my_val4").at_least_once
      facet2.expects(:items).returns([item3,item4]).at_least_once

      facet3 = mock()
      facet3.expects(:name).returns("my_facet3").at_least_once
      item5 = mock()
      item5.expects(:value).returns("my_val5").at_least_once
      item6 = mock()
      item6.expects(:value).returns("my_val6").at_least_once
      facet3.expects(:items).returns([item5,item6]).at_least_once
      response = mock()
      response.expects(:facets).returns([facet2,facet,facet3]).at_least_once
      helper.expects(:browse_response).returns(response)
      helper.expects(:facet_field_labels).returns("my_label").at_least_once
      helper.expects(:get_search_results).returns([response,mock()]).at_least_once
      browse_data = helper.get_exhibit_navigation_data
      browse_data.first.browse_levels.first.values.should == ["my_val","my_val2"]
      browse_data.first.browse_levels.first.selected.should == "my_val2"
      browse_data.first.browse_levels.second.values.should == ["my_val3","my_val4"]
      browse_data.first.browse_levels.second.selected.should == "my_val3"
      browse_data.first.browse_levels.fetch(2).values.should == ["my_val5","my_val6"]
      browse_data.first.browse_levels.fetch(2).selected.should == nil
    end

    it "should ignore a facet that is not present" do
      #must have a browse set and collection not nil
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      #add a browse level with label nil
      browse_level1 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:level_number=>1})
      browse_level2 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet2",:level_number=>2})
      @exhibit.expects(:browse_levels).returns([browse_level1,browse_level2]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)

      helper.expects(:params).returns({:collection_id=>@collection.id,:f=>{"my_facet"=>["my_val2"],"my_facet2"=>["my_val3"]}}).at_least_once
      facet = mock()
      facet.expects(:name).returns("my_facet").at_least_once
      item = mock()
      item.expects(:value).returns("my_val").at_least_once
      item2 = mock()
      item2.expects(:value).returns("my_val2").at_least_once
      facet.expects(:items).returns([item,item2]).at_least_once
      response = mock()
      response.expects(:facets).returns([facet]).at_least_once
      helper.expects(:browse_response).returns(response)
      helper.expects(:facet_field_labels).returns("my_label").at_least_once
      helper.expects(:get_search_results).returns([response,mock()]).at_least_once
      #second level facet not present so it should only return second level with no values even though first level has something selected
      browse_data = helper.get_exhibit_navigation_data
      browse_data.first.browse_levels.size.should == 2
      browse_data.first.browse_levels.first.values.should == ["my_val","my_val2"]
      browse_data.first.browse_levels.first.selected.should == "my_val2"
      browse_data.first.browse_levels.second.values.should == []
    end

    it "if 2 browse levels defined and two items selected it should handle having something selected at the lowest browse level" do
      #must have a browse set and collection not nil
      @collection.save
      @exhibit = Atrium::Exhibit.new({:atrium_collection_id=>@collection.id,:set_number=>1})
      @exhibit.save
      #add a browse level with label nil
      browse_level1 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet",:level_number=>1})
      browse_level2 = Atrium::BrowseLevel.new({:atrium_exhibit_id=>@exhibit.id,:solr_facet_name=>"my_facet2",:level_number=>2})
      @exhibit.expects(:browse_levels).returns([browse_level1,browse_level2]).at_least_once
      @collection.expects(:exhibits).returns([@exhibit]).at_least_once
      helper.stubs(:atrium_collection).returns(@collection)

      helper.expects(:params).returns({:collection_id=>@collection.id,:f=>{"my_facet"=>["my_val2"],"my_facet2"=>["my_val3"]}}).at_least_once
      facet = mock()
      facet.expects(:name).returns("my_facet").at_least_once
      item = mock()
      item.expects(:value).returns("my_val").at_least_once
      item2 = mock()
      item2.expects(:value).returns("my_val2").at_least_once
      facet.expects(:items).returns([item,item2]).at_least_once
      facet2 = mock()
      facet2.expects(:name).returns("my_facet2").at_least_once
      item3 = mock()
      item3.expects(:value).returns("my_val3").at_least_once
      item4 = mock()
      item4.expects(:value).returns("my_val4").at_least_once
      facet2.expects(:items).returns([item3,item4]).at_least_once
      response = mock()
      response.expects(:facets).returns([facet2,facet]).at_least_once
      helper.expects(:browse_response).returns(response)
      helper.expects(:facet_field_labels).returns("my_label").at_least_once
      helper.expects(:get_search_results).returns([response,mock()]).at_least_once
      browse_data = helper.get_exhibit_navigation_data
      browse_data.first.browse_levels.size.should == 2
      browse_data.first.browse_levels.first.values.should == ["my_val","my_val2"]
      browse_data.first.browse_levels.first.selected.should == "my_val2"
      browse_data.first.browse_levels.second.values.should == ["my_val3","my_val4"]
      browse_data.first.browse_levels.second.selected.should == "my_val3"
    end
  end
end
