#require 'rake/testtask'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'thor/core_ext/file_binary_read'

namespace :atrium do

  desc "Execute Continuous Integration build (docs, tests with coverage)"
  task :ci do
    Rake::Task["atrium:doc"].invoke
    Rake::Task["hydra:jetty:config"].invoke
    
    require 'jettywrapper'
    jetty_params = {
      :jetty_home => File.expand_path(File.dirname(__FILE__) + '/../jetty'),
      :quiet => false,
      :jetty_port => 8983,
      :solr_home => File.expand_path(File.dirname(__FILE__) + '/../jetty/solr'),
      :fedora_home => File.expand_path(File.dirname(__FILE__) + '/../jetty/fedora/default'),
      :startup_wait => 30
      }

    # does this make jetty run in TEST environment???
    error = Jettywrapper.wrap(jetty_params) do
      Rake::Task['atrium:setup_test_app'].invoke
      Rake::Task['solr:marc:index_test_data'].invoke
      #puts %x[rake atrium:fixtures:refresh RAILS_ENV=test] # calling hydra:fixtures:refresh from the root of the test app
      Rake::Task['atrium:test'].invoke
    end
    raise "test failures: #{error}" if error
  end

  
  desc "Easiest way to run rspec tests. Copies code to host plugins dir, loads fixtures, then runs specs - need to have jetty running."
  #task :spec => "rspec:setup_and_run"
  
  namespace :rspec do
      
    desc "Run the hydra-head specs - need to have jetty running, test host set up and fixtures loaded."
    task :run => :use_test_app do
			puts "Running rspec tests"
			puts  %x[rake atrium:spec:run]
      FileUtils.cd('../../')
    end
    
    desc "Sets up test host, loads fixtures, then runs specs - need to have jetty running."
    task :setup_and_run => ["atrium:setup_test_app"] do
			puts "Reloading fixtures"
      #puts %x[rake atrium:fixtures:refresh RAILS_ENV=test] # calling hydra:fixtures:refresh from the root of the test app
      Rake::Task["atrium:rspec:run"].invoke
    end
        
  end

  
  # The following is a task named :doc which generates documentation using yard
  begin
    require 'yard'
    require 'yard/rake/yardoc_task'
    project_root = File.expand_path("#{File.dirname(__FILE__)}/../")
    doc_destination = File.join(project_root, 'doc')
    if !File.exists?(doc_destination) 
      FileUtils.mkdir_p(doc_destination)
    end

    YARD::Rake::YardocTask.new(:doc) do |yt|
      readme_filename = 'README.textile'
      textile_docs = []
      Dir[File.join(project_root, "*.textile")].each_with_index do |f, index| 
        unless f.include?("/#{readme_filename}") # Skip readme, which is already built by the --readme option
          textile_docs << '-'
          textile_docs << f
        end
      end
      yt.files   = Dir.glob(File.join(project_root, '*.rb')) + 
                   Dir.glob(File.join(project_root, 'app', '**', '*.rb')) + 
                   Dir.glob(File.join(project_root, 'lib', '**', '*.rb')) + 
                   textile_docs
      yt.options = ['--output-dir', doc_destination, '--readme', readme_filename]
    end
  rescue LoadError
    desc "Generate YARD Documentation"
    task :doc do
      abort "Please install the YARD gem to generate rdoc."
    end
  end
  
  #
  # Cucumber
  #
  
  
  # desc "Easieset way to run cucumber tests. Sets up test host, refreshes fixtures and runs cucumber tests"
  # task :cucumber => "cucumber:setup_and_run"
  task :cucumber => "cucumber:run"
  

  namespace :cucumber do
   
   desc "Run cucumber tests for atrium - need to have jetty running, test host set up and fixtures loaded."
   task :run => :set_test_host_path do
     Dir.chdir(TEST_HOST_PATH)
     puts "Running cucumber features in test host app"
     puts %x[rake atrium:cucumber]
     # puts %x[cucumber --color --tags ~@pending --tags ~@overwritten features]
     raise "Cucumber tests failed" unless $?.success?
     FileUtils.cd('../../')
   end
 
   # desc "Sets up test host, loads fixtures, then runs cucumber features - need to have jetty running."
   # task :setup_and_run => ["atrium:setup_test_app", "atrium:remove_features_from_host", "atrium:copy_features_to_host"] do
   #   system("rake hydra:fixtures:refresh environment=test")
   #   Rake::Task["atrium:cucumber:run"].invoke
   # end    
  end
   
# Not sure if these are necessary - MZ 09Jul2011 
  # desc "Copy current contents of the features directory into TEST_HOST_PATH/test_support/features"
  # task :copy_features_to_host => [:set_test_host_path] do
  #   features_dir = "#{TEST_HOST_PATH}/test_support/features"
  #   excluded = [".", ".."]
  #   FileUtils.mkdir_p(features_dir)
  #   puts "Copying features to #{features_dir}"
  #   # puts %x[ls -l test_support/features/mods_asset_search_result.feature]
  #   %x[cp -R test_support/features/* #{features_dir}]
  # end
  # 
  # desc "Remove TEST_HOST_PATH/test_support/features"
  # task :remove_features_from_host => [:set_test_host_path] do
  #   features_dir = "#{TEST_HOST_PATH}/test_support/features"
  #   puts "Emptying out #{features_dir}"
  #   %x[rm -rf #{features_dir}]
  # end
  
  
  #
  # Misc Tasks
  #
  
  desc "Creates a new test app"
  task :setup_test_app => [:set_test_host_path] do
    # Thor::Util.load_thorfile('tasks/test_app_builder.thor', nil, nil)
    # klass, task = Thor::Util.find_class_and_task_by_namespace("hydra:test_app_builder:build")
    # klass.start([task])
      path = TEST_HOST_PATH
      errors = []
      puts "Cleaning out test app path"
      %x[rm -fr #{path}]
      errors << 'Error removing test app' unless $?.success?

      FileUtils.mkdir_p(path)
      
      puts "Copying over .rvmrc file"
      FileUtils.cp("./test_support/etc/rvmrc",File.join(path,".rvmrc"))
      FileUtils.cd("tmp")
      system("source ./test_app/.rvmrc")
      
      puts "Installing rails, bundler and devise"
      %x[gem install --no-rdoc --no-ri 'rails']
      %x[gem install --no-rdoc --no-ri 'bundler']
      %x[gem install --no-rdoc --no-ri 'devise']
      
      puts "Generating new rails app"
      %x[rails new test_app]
      errors << 'Error generating new rails test app' unless $?.success?
      FileUtils.cd('test_app')
      
      FileUtils.rm('public/index.html')


      after = 'TestApp::Application.configure do'
      replace!( "#{path}/config/environments/test.rb",  /#{after}/, "#{after}\n    config.log_level = :warn\n")
      

      puts "Copying Gemfile from test_support/etc"
      FileUtils.cp('../../test_support/etc/Gemfile','./Gemfile')

      puts "Creating local vendor/cache dir and copying gems from atrium gemset"
      FileUtils.cp_r(File.join('..','..','vendor','cache'), './vendor')
      
      puts "Copying fixtures into test app spec/fixtures directory"
      FileUtils.mkdir_p( File.join('.','test_support') )
      FileUtils.cp_r(File.join('..','..','test_support','fixtures'), File.join('.','test_support','fixtures'))
      
      puts "Executing bundle install --local"
      %x[bundle install --local]
      errors << 'Error running bundle install in test app' unless $?.success?

      puts "Installing cucumber in test app"
      %x[rails g cucumber:install]
      errors << 'Error installing cucumber in test app' unless $?.success?

      puts "generating default blacklight install"
      %x[rails generate blacklight --devise]
      errors << 'Error generating default blacklight install' unless $?.success?
      
      #puts "generating default hydra-head install"
      #%x[rails generate hydra:head -df]  # using -f to force overwriting of solr.yml
      #errors << 'Error generating default hydra-head install' unless $?.success?

      puts "generating default atrium install"
      %x[rails generate atrium -df] # using -f to force overwriting of solr.yml
      errors << 'Error generating default atrium install' unless $?.success?

      puts "Running rake db:migrate"
      %x[rake db:migrate]
      %x[rake db:migrate RAILS_ENV=test]
      raise "Errors: #{errors.join("; ")}" unless errors.empty?


    
    FileUtils.cd('../../')
    

  end
  
  task :set_test_host_path do
    TEST_HOST_PATH = File.join(File.expand_path(File.dirname(__FILE__)),'..','tmp','test_app')
  end
  
  #
  # Test
  #

  desc "Run tests against test app"
  task :test => [:use_test_app]  do
    
    puts "Running rspec tests"
    puts  %x[rake atrium:spec:rcov]

    puts "Running cucumber tests"
    puts %x[rake atrium:cucumber]

    FileUtils.cd('../../')
    puts "Completed test suite"
  end
  
  desc "Make sure the test app is installed, then run the tasks from its root directory"
  task :use_test_app => [:set_test_host_path] do
    Rake::Task['atrium:setup_test_app'].invoke unless File.exist?(TEST_HOST_PATH)
    FileUtils.cd(TEST_HOST_PATH)
  end
end


        # Adds the content to the file.
        #
        def replace!(destination, regexp, string)
          content = File.binread(destination)
          content.gsub!(regexp, string)
          File.open(destination, 'wb') { |file| file.write(content) }
        end