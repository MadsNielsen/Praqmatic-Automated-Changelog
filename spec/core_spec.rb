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

	describe "generate_settings" do

		context "cmd line args contains --properties with title" do
			it "should return a map with the title from the command line" do			
				allow(Core).to receive(:read_settings_file).with(an_instance_of(String)) {
					lines = [
						":properties:",
						"  title: 'PAC'",
						"  version: 2.0",
						"  otherstuff: other"
					].join("\n")
				}									
				arguments = { '--properties' => '{"title":"PAC Changelog Name"}' }
				settings_parsed = Core.generate_settings(arguments, Core.read_settings_file("something"))		
				expect(settings_parsed[:properties]['title']).to eql('PAC Changelog Name')
			end
		end

		context "cmd line args contains invalid --properties" do 
			it "should throw a parse error" do 
				allow(Core).to receive(:read_settings_file).with(an_instance_of(String)) {
					lines = [
						":properties:",
						"  title: 'PAC'",
						"  version: 2.0",
						"  otherstuff: other"
					].join("\n")
				}				
				arguments = { '--properties' => "{ title'PAC Chang} " }
				expect { Core.generate_settings(arguments, Core.read_settings_file("something")) }.to raise_error(JSON::ParserError)
			end
		end

		context "cmd line args overrides settings file" do 
			it "should override definition in settings file" do	
				allow(Core).to receive(:read_settings_file).with(an_instance_of(String)) {
					lines = [
						":properties:",
						"  title: 'PAC'",
						"  version: 2.0",
						"  otherstuff: other"
					].join("\n")
				}		

				arguments = { '--properties' => '{"title" : "PAC Changelog Name Override", "debug":"true" }' }
				settings_parsed = Core.generate_settings(arguments, Core.read_settings_file("dont-care"))
				expect(settings_parsed[:properties]['title']).to eql('PAC Changelog Name Override')
				expect(settings_parsed[:properties]['version']).to eql(2.0)
				expect(settings_parsed[:properties]['otherstuff']).to eql('other')
				expect(settings_parsed[:properties]['debug']).to eql("true")
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
				allow(Core).to receive(:read_settings_file).with(an_instance_of(String)) {
					lines = [
						":properties:",
						"  title: 'PAC'",
						"  version: 2.0",
						"  otherstuff: other",
						":task_systems:",
						"  -",
						"    :name: jira",
						"  -",
						"    :name: trac"
					].join("\n")
				}				
				settings_parsed = Core.generate_settings(arguments, Core.read_settings_file("something"))		
				expect(settings_parsed[:task_systems][1][:usr]).to eql('tracuser')
				expect(settings_parsed[:task_systems][1][:pw]).to eql('tracpassword')
				expect(settings_parsed[:task_systems][0][:usr]).to eql('newuser')
				expect(settings_parsed[:task_systems][0][:pw]).to eql('newpassword')				
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
