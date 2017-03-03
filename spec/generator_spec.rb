require_relative "../lib/model.rb"
require_relative "../lib/task.rb"
require_relative "../lib/decorators.rb"
require_relative "../lib/core.rb"
require_relative "../lib/report.rb"

RSpec.describe Report::Generator do

	describe "#render_template" do

		let(:generator) { Report::Generator.new }

		let(:simple_settings) { 
<<-eos
:general:
 
:templates:
  - { location: templates/default_id_report.md }

:task_systems:
  - 
    :name: none
    :regex:
      - { pattern: '/Issue:\s*(\d+)/i', label: none }
:vcs:
  :type: git
  :repo_location: '.'
eos
		}

		let(:simple_settings_with_properties) { 
<<-eos
:general:

:properties:
  title: 'Awesome Changelog Volume 42'
  extra: 'Extra Stuff' 
 
:templates:
  - { location: templates/default_id_report.md }

:task_systems:
  - 
    :name: none
    :regex:
      - { pattern: '/Issue:\s*(\d+)/i', label: none }
:vcs:
  :type: git
  :repo_location: '.'
eos
		}	

		let(:simple_template) { '# {{properties.title}}' }
		let(:not_so_simple_template) { '{{properties.title}} and {{properties.extra}}' }

		let(:simple) { 
			generator.to_liquid_properties(Core.generate_settings({ '--properties' =>  '{"title" : "Awesome Changelog Volume 2" }' }, simple_settings) )		
		}

		let(:less_simple) {
			generator.to_liquid_properties(Core.generate_settings({ '--properties' =>  '{"title" : "Awesome Changelog Volume 43" }' }, simple_settings_with_properties) )			
		}

		context "when the minimal template is used with cmd line --properties" do
			it "output should be produced" do
				render = generator.render_template(simple_template, simple)
				expect(render).to eql('# Awesome Changelog Volume 2')
			end
		end

		context "when --properties are defined in the cmd line" do
			it "output should be produced" do 
				render = generator.render_template(not_so_simple_template, less_simple)
				expect(render).to eql('Awesome Changelog Volume 43 and Extra Stuff')
			end
		end
	end
end