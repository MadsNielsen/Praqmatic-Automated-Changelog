require_relative "../lib/model.rb"
require_relative "../lib/decorators.rb"

RSpec.describe Model::PACTaskCollection do

	describe "length" do

		subject(:tasks) do
			Model::PACTaskCollection.new(tasks: [Model::PACTask.new('STACI-3A'), Model::PACTask.new('STACI-3B'), Model::PACTask.new('STACI-3C')])
		end			

		context "when 3 tasks have been found" do 
			it "the tasklist should contain 3 elements" do
				expect(tasks.length).to be 3
			end
		end

	end

	describe "by_label" do

		subject(:tasks) do
			Model::PACTaskCollection.new(tasks: [Model::PACTask.new('STACI-3A'), Model::PACTask.new('STACI-3B'), Model::PACTask.new('STACI-3C')])
		end			

		let(:taskModified) do
			commit1 = Model::PACCommit.new('abcd1234')
			tasks.each do |t|
				t.add_commit(commit1)
				t.label = 'STACI'
			end
			commit2 = Model::PACCommit.new('abcd1234abcd')
			task2 = Model::PACTask.new('STACI-4')
			task2.add_commit(commit2)
			task2.label = 'LUCI'
			tasks.add(task2)
			tasks
		end

		context "when grouping by label" do
			it "should return only the tasks with the specified label" do
				expect(taskModified.by_label['STACI'].length).to be 3
				expect(taskModified.by_label['LUCI'].length).to be 1
			end
		end
	end

	describe "add" do

		let(:collection) {
			Model::PACTaskCollection.new
		}

		let(:task1) {
			task = Model::PACTask.new(1)
		}  

		context "when add is used on a collection of tasks" do 
			it "should add the task to the collection index" do
				task = Model::PACTask.new(1)
				collection.add(task)
				expect(task).to eql(collection[1])
			end		
		end

		context "when an existing task is added to a collection" do	
			it "the task should not be duplicated in the collection" do
					collection.add(task1, task1)			
					expect(collection.length).to eql(1) 
			end

			it "commits should be collated per task without duplication" do
				task1.add_commit(Model::PACCommit.new('abcd1234'))
				task1.add_commit(Model::PACCommit.new('abcd1234'))
				task1.add_commit(Model::PACCommit.new('abcd1234abcd'))
				collection.add(task1)
				expect(collection[1].commits.length).to eql(2) 
			end
		end

		context "when more than one tasks is added to a collection" do

			c = Model::PACCommit.new('abcd1234')
			task2 = Model::PACTask.new(2)		

			it "adds all tasks to the collection" do
				task1.add_commit(c)
				task2.add_commit(c)
				collection.add(task1)
				collection.add(task2)
				expect(collection.length).to eql(2)
			end
		end
	end
end

RSpec.describe Model::PACTask do

	describe "extend" do
		subject(:task) do
			Model::PACTask.new('STACI-2')
		end

		context "when a task has not been extended" do
			it "the task should not have a data attribute" do
				expect(task.has?('data')).to be false
			end
		end

		context "when task is extended with JiraTaskDecorator" do
			it "the task should have a data attribute" do
				t = task.extend(JiraTaskDecorator)
				allow(t).to receive(:data) { { 'jira_data' => 'some_value'} }
				expect(t.has?('jira_data')).to be true
			end
		end
	end
end