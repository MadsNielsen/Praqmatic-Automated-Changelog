require_relative '../lib/core'

RSpec.describe Core do
	describe "read_settings" do	
		context "when settings file exists" do 
			it "returns the contents of the found settings file" do
				settings_file = File.join(File.dirname(__FILE__), '../default_settings.yml')
				arguments = { '--settings' => "#{settings_file}" }
				file_parsed = Core.read_settings_file(arguments)
				expect(file_parsed).not_to be_nil
			end
		end
		context "when settings file does not exist" do 
			it "throws an exception with description" do 
				settings_file = File.join(File.dirname(__FILE__), '../../default_settings_not.yml')
				arguments = { '--settings' => "#{settings_file}" }
				expect { Core.read_settings_file(arguments) }.to raise_error(RuntimeError)	
			end
		end
	end
end

RSpec.describe Core do

	describe "generate_settings" do

		before(:each) {
			@settings_file = Core.read_settings_file(File.join(File.dirname(__FILE__), '../../default_settings_not.yml'))
		}

		context "cmd line args contains --properties with title" do
			it "should return a map with the title from the command line" do			
				arguments = { '--properties' => '{"title":"PAC Changelog Name"}' }
				settings_parsed = Core.generate_settings(arguments, @settings_file)		
				expect(settings_parsed[:properties]['title']).to eql('PAC Changelog Name')
			end
		end

		context "cmd line args contains invalid --properties" do 
			it "should throw a parse error" do 
				arguments = { '--properties' => "{ title'PAC Chang} " }
				expect { Core.generate_settings(arguments, @settings_file) }.to raise_error(JSON::ParserError)
			end
		end

		context "cmd line args overrides settings file" do 
			it "should override definition in settings file" do			
				arguments = { '--properties' => '{"title" : "PAC Changelog Name Override" }' }
				settings_parsed = Core.generate_settings(arguments, @settings_file)
				expect(settings_parsed[:properties]['title']).to eql('PAC Changelog Name Override')
			end
		end

		context "cmd line contains credentials switch -c" do 

			let(:arguments) { 
				{
					'-c' => 2, 
					'<user>' => ["newuser", "tracuser"], 
					'<password>' => ["newpassword", "tracpassword"], 
					'<target>' => ["jira", "trac"] 
				}				
			}

			it ":jira section should include exactly 5 items" do
				settings_parsed = Core.generate_settings(arguments, @settings_file)		
				expect(settings_parsed[:task_systems][1].size).to eql(5)
				expect(settings_parsed[:task_systems][1][:usr]).to eql('newuser')
				expect(settings_parsed[:task_systems][1][:pw]).to eql('newpassword')
			end

		end

	end

end


	# def test_configuration_parsing
	# 	settings_file = File.join(File.dirname(__FILE__), '../../default_settings.yml')
	# 	loaded = YAML::load(File.open(settings_file))
	# 	assert_true(loaded.has_key?(:general))
	# 	assert_equal(3, loaded[:task_systems].length)
	# 	assert_equal(3, loaded[:templates].length)		
	# end

	# 	#The everything ok scenario
	# def test_properties_parsing_ok
	# 	settings_file = File.join(File.dirname(__FILE__), '../../default_settings.yml')
	# 	arguments = { '--settings' => "#{settings_file}", '--properties' => '{"title" : "PAC Changelog Name Override" }' }
	# 	file_parsed = Core.read_settings_file(arguments)
	# 	settings_parsed = Core.generate_settings(arguments, file_parsed)
	# 	assert_equal('PAC Changelog Name Override', settings_parsed[:properties]['title'])		
	# 	defined = Report::Generator.new.to_liquid_properties(settings_parsed)
	# 	assert_equal('PAC Changelog Name Override', defined['properties']['title'] )
	# 	assert_equal('PAC Changelog Name Override', settings_parsed[:properties]['title'])
	# end

		#Credentials test (test the -c option. for username and password overrides)
	# def test_configure_credentials
	# 	settings_file = File.join(File.dirname(__FILE__), '../../default_settings.yml')
	# 	#Notice the wierd way docopt handles it. The -c flag is a repeat flag, each option is then grouped positionally. So for each 'c' specified 
	# 	#c is incremented, and the index of the then the value specified.
	# 	arguments = { '--settings' => "#{settings_file}", '--properties' => '{"title" : "PAC Changelog Name Override" }', '-c' => 2, 
	# 		'<user>' => ["newuser", "tracuser"], 
	# 		'<password>' => ["newpassword", "tracpassword"], 
	# 		'<target>' => ["jira", "trac"] } 

	# 	file_parsed = Core.read_settings_file(arguments)
	# 	settings_parsed = Core.generate_settings(arguments, file_parsed)		
	# 	assert_equal('newuser', settings_parsed[:task_systems][1][:usr])
	# 	assert_equal('newpassword', settings_parsed[:task_systems][1][:pw])

	# 	assert_equal('tracuser', settings_parsed[:task_systems][2][:usr])
	# 	assert_equal('tracpassword', settings_parsed[:task_systems][2][:pw])
	# end