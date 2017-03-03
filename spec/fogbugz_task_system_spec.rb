require_relative '../lib/core'
require_relative '../lib/task'
require_relative '../lib/model'

RSpec.describe Task::FogBugzTaskSystem, "#apply"  do

	before(:each) {
  	@c_noprops = <<-eos
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

  	@c_props = <<-eos
:general:
  date_template: '%Y-%m-%d'
:properties:
  title: 'Awesome Changelog Volume 42'
  extra: 'Extra Stuff' 
:templates:
  - { location: templates/default_id_report.md}
:task_systems:
  - 
    :name: none
    :regex:
      - { pattern: '/Issue:\s*(\d+)/i', label: none }
:vcs:
  :type: git
  :repo_location: '.'
eos

  	@min_template = '# {{properties.title}}'		
	}

	context "when apply is used with invalid fogbugz url" do
		it "the apply method should return false" do
			settings = { :name => 'fogbugz', :query_string => 'http://www.praqma.com/#{task_id}', :usr => 'usr_fb', :pw => 'pw_fb' }
			collection = Model::PACTaskCollection.new
			task = Model::PACTask.new 'Fogbugz1'
			task.applies_to = 'fogbugz'
			collection.add(task)
			fogbugz = Task::FogBugzTaskSystem.new(settings).apply(collection)
			expect(fogbugz).to be_falsey 
		end 
	end	
end