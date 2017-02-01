module VCSIntegration

  require 'fileutils'
  require 'open3'
  require_relative '../../lib/core'
  require_relative '../../lib/model'
  require 'pp'
  require 'zip/zip'
  require 'ci/reporter/rake/test_unit_loader.rb'  

  class IncludesSince < Test::Unit::TestCase

    # Helper function to unzip our repo
    def unzip_file (file, destination)
      Zip::ZipFile.open(file) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
        puts "Successfully extracted"
      }
    end

    # Test setup: executed before each test
    def setup
      unzip_file("test/resources/IncludesSinceTestRepository.zip", "test/resources")
    end

    # Executed after each test
    def teardown
      FileUtils.rm_rf("test/resources/IncludesSinceTestRepository")
    end

    def test_includesSince_tag      
      settings_file = File.join(File.dirname(__FILE__), '../resources/IncludesSinceTestRepository_settings.yml')

      settings = YAML::load(File.open(settings_file))

      Core.settings = settings
      #Returns a PACCommitCollection
      commit_map = Core.vcs.get_delta('v1.0') # Since Commit 1
      # These are the commits AFTER the 1.0 tag
      assert_true(commit_map.commits.include?(Model::PACCommit.new("dfd8fd3ade868072f31701aac6fba1f2cf965dd7"))) # Commit 3
      assert_true(commit_map.commits.include?(Model::PACCommit.new("62f42e26a401524637839ba4ff969194303cff7c"))) # Commit 2
      # This is the commit OF the 1.0Modelg
      assert_true(!commit_map.commits.include?(Model::PACCommit.new("7164ed9cec32195e44c7f2a2abd764df37921863"))) # Commit 1
    end

    def test_includesSince_sha      
      settings_file = File.join(File.dirname(__FILE__), '../resources/IncludesSinceTestRepository_settings.yml')
      settings = YAML::load(File.open(settings_file))
      Core.settings = settings
      commit_map = Core.vcs.get_delta('7164ed9cec32195e44c7f2a2abd764df37921863') # Since Commit 1
      # These are the commits AFTER the 1.0 tag
      assert_true(commit_map.commits.include?(Model::PACCommit.new("dfd8fd3ade868072f31701aac6fba1f2cf965dd7"))) # Commit 3
      assert_true(commit_map.commits.include?(Model::PACCommit.new("62f42e26a401524637839ba4ff969194303cff7c"))) # Commit 2
      # This is the commit OF the 1.0 tag
      assert_true(!commit_map.commits.include?(Model::PACCommit.new("7164ed9cec32195e44c7f2a2abd764df37921863"))) # Commit 1
    end
  end # class

  class IdReport < Test::Unit::TestCase
    # Order in which to run the test.
    # Order matters here as we need to run simulator first to get logfile
    # parse
    self.test_order = :alphabetic

    # Helper function to unzip our repo
    def unzip_file (file, destination)
      Zip::ZipFile.open(file) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
        puts "Successfully extracted"
      }
    end

    # Test setup: executed before each test
    def setup
      unzip_file("test/resources/idReportTestRepository.zip", "test/resources")
    end

    # Executed after each test
    def teardown
      FileUtils.rm_rf("test/resources/idReportTestRepository")
    end

    def test_mytest      
      settings_file = File.join(File.dirname(__FILE__), '../resources/idReportTestRepository_settings.yml')

      settings = YAML::load(File.open(settings_file))

      Core.settings = settings
      #PACCommitCollection
      commit_map = Core.vcs.get_delta("f9a66ca6d2e616b1012a1bdeb13f924c1bc9b4b6", "fb493078d9f42d79ea0e3a56abca7956a0d47123")
      pp "#################################"
      pp "Commit map for the repository is:"
      pp commit_map

      pp "##############################################"
      pp "grouped by tasks ids the commits are"
      #PACTaskCollection
      task_list = Core.task_id_list(commit_map)
      pp task_list

      pp "Checking with test asserts if the id expected are there:"
      # based on our created test repository
      assert_false(task_list["1"].nil?, "Didn't find task reference for '1' in the repository as expected")
      assert_false(task_list["2"].nil?, "Didn't find task reference for '2' in the repository as expected #{task_list.tasks}")
      assert_false(task_list["3"].nil?, "Didn't find task reference for '3' in the repository as expected")
      pp "DONE - asserts okay for expected ids"

      pp "##############################################"
      pp "Un-referenced commits are:"
      pp task_list.unreferenced_commits

      pp "Checking with test asserts for un-referenced commits :"
      # Checking on unreferenced shas:
      pp task_list.unreferenced_commits
      #assert_equal(task_list.unreferenced.first.commits.class, Array)
      #assert_equal(2, task_list.unreferenced.first.commit_collection.commits.length)
      assert_true(task_list["none"].commits.include?(Model::PACCommit.new("a789b472150f462a8ae291577dcf7557b2b4ca55")))
      assert_true(task_list.unreferenced_commits.include?(Model::PACCommit.new("55857d4e9838d1855b10e4c30b43a433e2db47cd")))
      pp "DONE - assert okay for un-referenced commits"
    end

  end # class  

  # This test class have tests that verifies that we collect the correct commits
  # for a given repository called pac-test-repo.zip.
  # The test repository is contructed in a way that holds branches that are not merged
  # in yet, as well as merged branches. Merges are done like the Pretested Integration Plugin
  # for the Automated Git flow would do it (git merge -no-ff).
  # These verifications are do ensure the tree-walker traversing the git commits
  # follows the correct path in the topological search.
  #
  # These test cases are created based on a specific user case, where an issue was found
  # if the history had certain topoplog. Problem was the walker collecting the git commits
  # wasn't following topological order, but data order. Thus the pac-test-repo repository
  # created shows exactly this problem.
  #
  # Every test have three phases, each one verifies two lists - whitelist and blacklist
  # 1. Verify whitelist, that is all commits on the branch (master) between topological 
  # order of from and to SHA givens is collected. Blacklist is those commits not expected to be found, those only belonging to a branch that is not master
  # 2. Verifies whitelist of issue numbers (id, or references they are also called) which is a list of references found in the commit message. 
  # The blacklist are those issue numbers we do not expect because they are in commits that should be found.
  # 3. The un-referenced verification is checking that all commits that doesn't have a reference is in our list of such commits, while there should be no
  # commits there if they have a reference. The un-references list of commits is typically presented in the report.
  class TopologyWalkerIssueTest < Test::Unit::TestCase

    # Order in which to run the test.
    # Order matters here as we need to run simulator first to get logfile
    # parse
    self.test_order = :alphabetic

    # Helper function to unzip our repo
    def unzip_file (file, destination)
      Zip::ZipFile.open(file) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
        puts "Successfully extracted"
      }
    end

    # Test setup: executed before each test
    def setup
      unzip_file("test/resources/pac-test-repo.zip", "test/resources")
    end

    # Executed after each test
    def teardown
      FileUtils.rm_rf("test/resources/pac-test-repo")
    end
    
    # Verifies that all commits on the master are found correct and only commit from master.
    def test_check_commit_found_on_master
      pp "******************************************************"
      pp " test_check_commit_found_on_master"
      pp "******************************************************"      
      settings_file = File.join(File.dirname(__FILE__), '../resources/pac-test-repo_settings.yml')
      settings = YAML::load(File.open(settings_file))    
      branch = "master"
      # make sure we are on the expected branch as tests run abitrary orders
      system("cd test/resources/pac-test-repo && git checkout #{ branch}")
      Core.settings = settings
      # both these are on master, first and last commit on master
      # ./pac.rb --sha <to> []<from>]
      from = "d926b6bf510abcda2ceff4ad01693a694e65141a"
      to = "c1ece74c3411d0f19c49a1b193d3a8aec7376aa1"  ## note that c16bd71 is not last commit, last one is b437bdc - this affect what we verifies below :-)
      commit_map = Core.vcs.get_delta(to, from)
           
      pp "########################################################################################"
      pp "All commit found between 'from' SHA #{ from } and 'to' SHA #{ to } on branch #{ branch }"
      pp "is in the commit map:"
      pp "########################################################################################"
      pp commit_map
      pp "########################################################################################"

      expected_SHAs = [
        Model::PACCommit.new("d926b6bf510abcda2ceff4ad01693a694e65141a"),
        Model::PACCommit.new("f5bcb543a73e7d168f1c99c1da1ae0b9f84f3543"),
        Model::PACCommit.new("3e2b00ad7b844d4708d7320788d2b54f917e4640"),
        Model::PACCommit.new("1fbeb9eda1d620d44208c919f326f7e16485b16f"),
        Model::PACCommit.new("e364d0e8c58efcc1069d516f83f14660df0a7dcd"),
        Model::PACCommit.new("24cf861d3ca6da1af780c72cd39ca16f5b90dc56"),
        Model::PACCommit.new("9439c822426bff6ac8bfebb66a893a281872ba38"),
        Model::PACCommit.new("7088338c011cbcfaa69cb3a14bd12553f9b42584"),
        Model::PACCommit.new("4069c1010c7536acb584411fd71657eeb27eda65")
      ]

      # All branches are merged to master
      not_expected_SHAs = []

      pp "Checking with test asserts if the SHAs expected are found..."
      # based on our created test repository
      expected_SHAs.each do |commit|
        assert_true(commit_map.commits.include?(commit), "Commit map didn't contain the expected SHA which is on #{ branch }: #{commit.sha}")
      end
      not_expected_SHAs.each do |sha|
        assert_false(commit_map.commits.include?(sha), "Commit map included SHA that was NOT expected (does not exist on #{branch}: #{commit.sha}")
      end
      pp "DONE - asserts okay for expected SHAs"

      grouped_by_task_id = Core.task_id_list(commit_map)
      pp "########################################################################################"
      pp "List of all task ids (references) in the commits just found:"
      pp "########################################################################################"
      pp grouped_by_task_id
      pp "########################################################################################"

      pp "Checking with test asserts if the id expected are there:"
      # expected ids are all those task ids that matches our regexp in the configuration file
      # but only in those commits in the commit map above
      expected_ids = [
        "1"
      ]

      expected_ids.each do |id|
        assert_not_nil(grouped_by_task_id[id], "Didn't find task reference for #{id} as expected: #{grouped_by_task_id.tasks}")
      end

      # These commits does not have task id references, but are found on the branch we traverse
      expected_unreferenced_SHAs = [
        Model::PACCommit.new("d926b6bf510abcda2ceff4ad01693a694e65141a"),
        Model::PACCommit.new("f5bcb543a73e7d168f1c99c1da1ae0b9f84f3543"),
        Model::PACCommit.new("3e2b00ad7b844d4708d7320788d2b54f917e4640"),
        Model::PACCommit.new("1fbeb9eda1d620d44208c919f326f7e16485b16f"),
        Model::PACCommit.new("e364d0e8c58efcc1069d516f83f14660df0a7dcd"),
        Model::PACCommit.new("24cf861d3ca6da1af780c72cd39ca16f5b90dc56"),
        Model::PACCommit.new("7088338c011cbcfaa69cb3a14bd12553f9b42584"),
        Model::PACCommit.new("4069c1010c7536acb584411fd71657eeb27eda65")
      ]
      
      # These are all commits on the branch we traverse, without a task id that matches our
      # regexp in the configuration file, as well as all those commits (with or without task ids
      # that is not on the branch
      referenced_SHAs = [
        Model::PACCommit.new("9439c822426bff6ac8bfebb66a893a281872ba38" )
      ]

      pp "Checking with test asserts for un-referenced commits :"
      # Checking on unreferenced shas:
      expected_unreferenced_SHAs.each do |commit|
        assert_true(grouped_by_task_id.unreferenced_commits.include?(commit), "Found a SHA in unreferenced SHAs, those without issue reference, that was not expected: #{commit.sha}")
      end      
      referenced_SHAs.each do |commit|
        assert_false(grouped_by_task_id.unreferenced_commits.include?(commit), "Found a SHA in unreferenced SHAs, those without issue reference, that was not expected: #{commit.sha}")
      end
      pp "DONE - assert okay for un-referenced commits"

    end
  end # class  
  # This test class have tests that verifies that we collect the correct commits
  # for a given repository called GetCommitMessagesTestRepository.zip.
  # The test repository is contructed in a way that holds branches that are not merged
  # in yet, as well as merged branches. Merges are done like the Pretested Integration Plugin
  # for the Automated Git flow would do it (git merge -no-ff).
  # These verifications are do ensure the tree-walker traversing the git commits
  # follows the correct path in the topological search.
  #
  # Every test have three phases, each one verifies two lists - whitelist and blacklist
  # 1. Verify whitelist, that is all commits on the branch (master) between topological 
  # order of from and to SHA givens is collected. Blacklist is those commits not expected to be found, those only belonging to a branch that is not master
  # 2. Verifies whitelist of issue numbers (id, or references they are also called) which is a list of references found in the commit message. 
  # The blacklist are those issue numbers we do not expect because they are in commits that should be found.
  # 3. The un-referenced verification is checking that all commits that doesn't have a reference is in our list of such commits, while there should be no
  # commits there if they have a reference. The un-references list of commits is typically presented in the report.
  class TopologyWalkerBranches < Test::Unit::TestCase

    # Order in which to run the test.
    # Order matters here as we need to run simulator first to get logfile
    # parse
    self.test_order = :alphabetic

    # Helper function to unzip our repo
    def unzip_file (file, destination)
      Zip::ZipFile.open(file) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
        puts "Successfully extracted"
      }
    end

    # Test setup: executed before each test
    def setup
      unzip_file("test/resources/GetCommitMessagesTestRepository.zip", "test/resources")
    end

    # Executed after each test
    def teardown
      FileUtils.rm_rf("test/resources/GetCommitMessagesTestRepository")
    end
    
    # This is just for reference - it is all our commits from the test repo and their branch
    # they belong to (15 commits in total):
    Modell_shas_and_their_branches = [
      Model::PACCommit.new("969e8311164b1086006edfee1d291c04da651cf9"), #no task id, branch dev2
      Model::PACCommit.new("2f4237b8dff65ec3caf842dc68106f34f8bc0cca"), #task id 200, branch dev2
      Model::PACCommit.new("15d2ad0ee10c4cfc3518ad6e5ce257ab9f47febb"), #task id 400, branch dev4
      Model::PACCommit.new("b20b118dd5986215bf0d76ad73a245433ba6768a"), #task id 100, branch master dev4, Merge: 9d87738 79b8eeb
      Model::PACCommit.new("79b8eebc8285389e31af5f585adc880d689f84fd"), #no task id, branch master dev4
      Model::PACCommit.new("2575481f9344e51bd4ee7f706eb7b2ef2e8153d2"), #no task id, branch master dev4
      Model::PACCommit.new("6bd7623fcf1cbbd41f16bda978cecab6b65a6e99"), #no task id, branch master dev4, Merge: 4c82d62 9d87738
      Model::PACCommit.new("9d8773840c88c7e41ec57e2aeacb4fa444775ecf"), #task id 300, 301, branch master dev4, Merge: 9e27dfa 6512e4f
      Model::PACCommit.new("6512e4f6590ac4aa17c03ed333c317110fddc3f1"), #task id 301, branch master dev4
      Model::PACCommit.new("cb7a8dc1836d910fc1856df77c2f63029bd1c7cd"), #task id 300, branch master dev4
      Model::PACCommit.new("9e27dfa978004cb4845312d01c4a63da94e5f356"), #task id 5, branch master dev4
      Model::PACCommit.new("20e5168e026bb57720dddb5e94a8074d68c54748"), #task id 4, branch master dev4
      Model::PACCommit.new("4c82d62935e78f741d04e2e4b6f0e5a83f05cbfa"), #task id 100, branch master dev4
      Model::PACCommit.new("996967baae8b4cb9f862f18c31fb5d42bdd4439c"), #task id 3, branch master dev2 dev4
      Model::PACCommit.new("c533da1bc3b74c55e58f27e7ac32cf2cb19be24d"), #no task id, initial commit, branch master dev2 dev4
    ]
    
    # Verifies that all commits on the master are found correct and only commit from master.
    def test_check_commit_found_on_master
      pp "******************************************************"
      pp " test_check_commit_found_on_master"
      pp "******************************************************"
      settings_file = File.join(File.dirname(__FILE__), '../resources/GetCommitMessagesTestRepository_settings.yml')
      settings = YAML::load(File.open(settings_file))
      
      branch="master"
      # make sure we are on the expected branch as tests run abitrary orders
      system("cd test/resources/GetCommitMessagesTestRepository && git checkout #{ branch}")

      Core.settings = settings
      # both these are on master, first and last commit on master
      # ./pac.rb --sha <to> []<from>]
      from="b20b118dd5986215bf0d76ad73a245433ba6768a"
      to="996967baae8b4cb9f862f18c31fb5d42bdd4439c"  ## note that this is not last commit, last one is c533da1bc3b74c55e58f27e7ac32cf2cb19be24d - this affect what we verifies below :-)
      commit_map = Core.vcs.get_delta(to,from)
      pp "########################################################################################"
      pp "All commit found between 'from' SHA #{ from } and 'to' SHA #{ to } on branch #{ branch }"
      pp "is in the commit map:"
      pp "########################################################################################"
      pp commit_map
      pp "########################################################################################"

      # We expect the following SHA in the commit map, as they are found on the branch:
      expected_SHAs = [
        Model::PACCommit.new("b20b118dd5986215bf0d76ad73a245433ba6768a"), #task id 100, branch master dev4, Merge: 9d87738 79b8eeb
        Model::PACCommit.new("79b8eebc8285389e31af5f585adc880d689f84fd"), #no task id, branch master dev4
        Model::PACCommit.new("2575481f9344e51bd4ee7f706eb7b2ef2e8153d2"), #no task id, branch master dev4
        Model::PACCommit.new("6bd7623fcf1cbbd41f16bda978cecab6b65a6e99"), #no task id, branch master dev4, Merge: 4c82d62 9d87738
        Model::PACCommit.new("9d8773840c88c7e41ec57e2aeacb4fa444775ecf"), #task id 300, 301, branch master dev4, Merge: 9e27dfa 6512e4f
        Model::PACCommit.new("6512e4f6590ac4aa17c03ed333c317110fddc3f1"), #task id 301, branch master dev4
        Model::PACCommit.new("cb7a8dc1836d910fc1856df77c2f63029bd1c7cd"), #task id 300, branch master dev4
        Model::PACCommit.new("9e27dfa978004cb4845312d01c4a63da94e5f356"), #task id 5, branch master dev4
        Model::PACCommit.new("20e5168e026bb57720dddb5e94a8074d68c54748"), #task id 4, branch master dev4
        Model::PACCommit.new("4c82d62935e78f741d04e2e4b6f0e5a83f05cbfa") #task id 100, branch master dev4
      #Commented out because of FB13433 - Tail commit is NOT included.
      #"996967baae8b4cb9f862f18c31fb5d42bdd4439c", #task id 3, branch master dev2 dev4
      ]
      # These commits should not be in the commit map, as they do not belong the branch
      not_expected_SHAs = [
        Model::PACCommit.new("c533da1bc3b74c55e58f27e7ac32cf2cb19be24d"), # on master, but it is the last one and we stop with <to> SHA just before
        Model::PACCommit.new("969e8311164b1086006edfee1d291c04da651cf9"), #no task id, branch dev2
        Model::PACCommit.new("2f4237b8dff65ec3caf842dc68106f34f8bc0cca"), #task id 200, branch dev2
        Model::PACCommit.new("15d2ad0ee10c4cfc3518ad6e5ce257ab9f47febb"), #task id 400, branch dev4   
      ] 
 
      pp "Checking with test asserts if the SHAs expected are found..."
      # based on our created test repository

      expected_SHAs.each do |commit|
        assert_true(commit_map.commits.include?(commit), "Commit map didn't contain the expected SHA which is on #{ branch }: #{commit.sha}")
      end 
      not_expected_SHAs.each do |commit|
        assert_false(commit_map.commits.include?(commit), "Commit map included SHA that was NOT expected (does not exist on #{ branch }): #{commit.sha}")
      end
      pp "DONE - asserts okay for expected SHAs"

      grouped_by_task_id = Core.task_id_list(commit_map)
      pp "########################################################################################"
      pp "List of all task ids (references) in the commits just found:"
      pp "########################################################################################"
      pp grouped_by_task_id
      pp "########################################################################################"

      pp "Checking with test asserts if the id expected are there:"
      # expected ids are all those task ids that matches our regexp in the configuration file
      # but only in those commits in the commit map above
      expected_ids = [
        "4",
        "100",
        "5",
        "300",
        "301",
      ]
      # obvious these ids are from the commits not found, thus the these task ids should be found either
      not_expected_ids = [
        "400",
        "200"
      ]
      expected_ids.each do |id|
        assert_not_nil(grouped_by_task_id[id], "Didn't find task reference for #{id} as expected: #{grouped_by_task_id.tasks}")
      end
      not_expected_ids.each do |id|
        assert_nil(grouped_by_task_id[id], "Found task reference for #{id} which was NOT expected")
      end
      pp "DONE - asserts okay for expected ids"


      unreferenced = grouped_by_task_id.unreferenced_commits
      pp "########################################################################################"
      pp "List of all commit that doesn't have a task ids (references):"
      pp "########################################################################################"
      pp unreferenced
      pp "########################################################################################"
      # These commits does not have task id references, but are found on the branch we traverse
      expected_unreferenced_SHAs = [
        Model::PACCommit.new("79b8eebc8285389e31af5f585adc880d689f84fd"), #no task id, branch master dev4
        Model::PACCommit.new("2575481f9344e51bd4ee7f706eb7b2ef2e8153d2"), #no task id, branch master dev4
        Model::PACCommit.new("6bd7623fcf1cbbd41f16bda978cecab6b65a6e99"), #no task id, branch master dev4, Merge: 4c82d62 9d87738
      ]
      
      # These are all commits on the branch we traverse, without a task id that matches our
      # regexp in the configuration file, as well as all those commits (with or without task ids
      # that is not on the branch
      not_expected_unreferenced_SHAs = [
        Model::PACCommit.new("969e8311164b1086006edfee1d291c04da651cf9"), #no task id, branch dev2
        Model::PACCommit.new("2f4237b8dff65ec3caf842dc68106f34f8bc0cca"), #task id 200, branch dev2
        Model::PACCommit.new("15d2ad0ee10c4cfc3518ad6e5ce257ab9f47febb"), #task id 400, branch dev4
        Model::PACCommit.new("b20b118dd5986215bf0d76ad73a245433ba6768a"), #task id 100, branch master dev4, Merge: 9d87738 79b8eeb
        Model::PACCommit.new("9d8773840c88c7e41ec57e2aeacb4fa444775ecf"), #task id 300, 301, branch master dev4, Merge: 9e27dfa 6512e4f
        Model::PACCommit.new("6512e4f6590ac4aa17c03ed333c317110fddc3f1"), #task id 301, branch master dev4
        Model::PACCommit.new("cb7a8dc1836d910fc1856df77c2f63029bd1c7cd"), #task id 300, branch master dev4
        Model::PACCommit.new("9e27dfa978004cb4845312d01c4a63da94e5f356"), #task id 5, branch master dev4
        Model::PACCommit.new("20e5168e026bb57720dddb5e94a8074d68c54748"), #task id 4, branch master dev4
        Model::PACCommit.new("4c82d62935e78f741d04e2e4b6f0e5a83f05cbfa"), #task id 100, branch master dev4
        Model::PACCommit.new("996967baae8b4cb9f862f18c31fb5d42bdd4439c"), #task id 3, branch master dev2 dev4
        Model::PACCommit.new("c533da1bc3b74c55e58f27e7ac32cf2cb19be24d"), #not included in <to>-<from> range, and no task id, initial commit, branch master dev2 dev4
      ]

      pp "Checking with test asserts for un-referenced commits :"
      # Checking on unreferenced shas:
      expected_unreferenced_SHAs.each do |commit|
        assert_true(unreferenced.include?(commit), "Found a SHA in unreferenced SHAs, those without issue reference, that was not expected: #{commit.sha}")
      end
      
      not_expected_unreferenced_SHAs.each do |commit|
        assert_false(unreferenced.include?(commit), "Found a SHA in unreferenced SHAs, those without issue reference, that was not expected: #{commit.sha}")
      end
      pp "DONE - assert okay for un-referenced commits"

    end
    
    # Verifies that all commits on the master are found correct and only commit from dev2.
    def test_check_commit_dev2
      pp "******************************************************"
      pp " test_check_commit_dev2"
      pp "******************************************************"
      
      settings_file = File.join(File.dirname(__FILE__), '../resources/GetCommitMessagesTestRepository_settings.yml')
      settings = YAML::load(File.open(settings_file))
      
      branch="dev2"
      # make sure we are on the expected branch as tests run abitrary orders
      system("cd test/resources/GetCommitMessagesTestRepository && git checkout #{ branch}")

      Core.settings = settings
        # both these are on master, first and last commit on master
      # ./pac.rb --sha <to> []<from>]
      from="969e8311164b1086006edfee1d291c04da651cf9"
      to="2f4237b8dff65ec3caf842dc68106f34f8bc0cca"
      commit_map = Core.vcs.get_delta(to,from)
      
      pp "########################################################################################"
      pp "All commit found between 'from' SHA #{ from } and 'to' SHA #{ to } on branch #{ branch }"
      pp "is in the commit map:"
      pp "########################################################################################"
      pp commit_map
      pp "########################################################################################"

      # We expect the following SHA in the commit map, as they are found on the branch:
      expected_SHAs =  [
        # not included, they are after the stop SHA given
        #"996967baae8b4cb9f862f18c31fb5d42bdd4439c", #task id 3, branch master dev2 dev4
        #"c533da1bc3b74c55e58f27e7ac32cf2cb19be24d", #no task id, initial commit, branch master dev2 dev4
       Model::PACCommit.new("969e8311164b1086006edfee1d291c04da651cf9")#, #no task id, branch dev2
       #"2f4237b8dff65ec3caf842dc68106f34f8bc0cca", #task id 200, branch dev2
        ]
      # These commits should not be in the commit map, as they do not belong the branch        
      not_expected_SHAs = [
        Model::PACCommit.new("996967baae8b4cb9f862f18c31fb5d42bdd4439c"), #task id 3, branch master dev2 dev4
        Model::PACCommit.new("c533da1bc3b74c55e58f27e7ac32cf2cb19be24d"), #no task id, initial commit, branch master dev2 dev4
        Model::PACCommit.new("15d2ad0ee10c4cfc3518ad6e5ce257ab9f47febb"), #task id 400, branch dev4
        Model::PACCommit.new("b20b118dd5986215bf0d76ad73a245433ba6768a"), #task id 100, branch master dev4, Merge: 9d87738 79b8eeb
        Model::PACCommit.new("79b8eebc8285389e31af5f585adc880d689f84fd"), #no task id, branch master dev4
        Model::PACCommit.new("2575481f9344e51bd4ee7f706eb7b2ef2e8153d2"), #no task id, branch master dev4
        Model::PACCommit.new("6bd7623fcf1cbbd41f16bda978cecab6b65a6e99"), #no task id, branch master dev4, Merge: 4c82d62 9d87738
        Model::PACCommit.new("9d8773840c88c7e41ec57e2aeacb4fa444775ecf"), #task id 300, 301, branch master dev4, Merge: 9e27dfa 6512e4f
        Model::PACCommit.new("6512e4f6590ac4aa17c03ed333c317110fddc3f1"), #task id 301, branch master dev4
        Model::PACCommit.new("cb7a8dc1836d910fc1856df77c2f63029bd1c7cd"), #task id 300, branch master dev4
        Model::PACCommit.new("9e27dfa978004cb4845312d01c4a63da94e5f356"), #task id 5, branch master dev4
        Model::PACCommit.new("20e5168e026bb57720dddb5e94a8074d68c54748"), #task id 4, branch master dev4
        Model::PACCommit.new("4c82d62935e78f741d04e2e4b6f0e5a83f05cbfa"), #task id 100, branch master dev4
        ]
      
      pp "Checking with test asserts if the SHAs expected are found..."
      # based on our created test repository
      expected_SHAs.each do |commit|
        assert_true(commit_map.commits.include?(commit), "Commit map didn't contain the expected SHA which is on #{branch}: #{commit.sha}")
      end
      not_expected_SHAs.each do |commit|
        assert_false(commit_map.commits.include?(commit), "Commit map included SHA that was NOT expected (does not exist on #{ branch }): #{commit.sha}")
      end
      pp "DONE - asserts okay for expected SHAs"          
      
      grouped_by_task_id = Core.task_id_list(commit_map)
      pp "########################################################################################"
      pp "List of all task ids (references) in the commits just found:"
      pp "########################################################################################"
      pp grouped_by_task_id
      pp "########################################################################################"

      pp "Checking with test asserts if the id expected are there:"
      # expected ids are all those task ids that matches our regexp in the configuration file
      # but only in those commits in the commit map above
      expected_ids = [
        #"200"
      ]
      # obvious these ids are from the commits not found, thus the these task ids should be found either
      not_expected_ids = [
        "3",
        "400",
        "4",
        "100",
        "5",
        "300",
        "301",
      ]
 
      expected_ids.each do |id|
        assert_not_nil(grouped_by_task_id[id], "Didn't find task reference for #{id} as expected")
      end

      not_expected_ids.each do |id|
        assert_nil(grouped_by_task_id[id], "Found task reference for #{id} which was NOT expected")
      end
      pp "DONE - asserts okay for expected ids"
      
      
      
      unreferenced = grouped_by_task_id.unreferenced_commits
      pp "########################################################################################"
      pp "List of all commit that doesn't have a task ids (references):"
      pp "########################################################################################"
      pp unreferenced
      pp "########################################################################################"
      # These commits does not have task id references, but are found on the branch we traverse
      expected_unreferenced_SHAs = [
        Model::PACCommit.new("969e8311164b1086006edfee1d291c04da651cf9") #no task id, branch dev2
      ]

      # These are all commits on the branch we traverse, without a task id that matches our
      # regexp in the configuration file, as well as all those commits (with or without task ids
      # that is not on the branch
      not_expected_unreferenced_SHAs = [
        Model::PACCommit.new("2f4237b8dff65ec3caf842dc68106f34f8bc0cca"), #task id 200, branch dev2
        Model::PACCommit.new("15d2ad0ee10c4cfc3518ad6e5ce257ab9f47febb"), #task id 400, branch dev4
        Model::PACCommit.new("b20b118dd5986215bf0d76ad73a245433ba6768a"), #task id 100, branch master dev4, Merge: 9d87738 79b8eeb
        Model::PACCommit.new("79b8eebc8285389e31af5f585adc880d689f84fd"), #no task id, branch master dev4
        Model::PACCommit.new("2575481f9344e51bd4ee7f706eb7b2ef2e8153d2"), #no task id, branch master dev4
        Model::PACCommit.new("6bd7623fcf1cbbd41f16bda978cecab6b65a6e99"), #no task id, branch master dev4, Merge: 4c82d62 9d87738
        Model::PACCommit.new("9d8773840c88c7e41ec57e2aeacb4fa444775ecf"), #task id 300, 301, branch master dev4, Merge: 9e27dfa 6512e4f
        Model::PACCommit.new("6512e4f6590ac4aa17c03ed333c317110fddc3f1"), #task id 301, branch master dev4
        Model::PACCommit.new("cb7a8dc1836d910fc1856df77c2f63029bd1c7cd"), #task id 300, branch master dev4
        Model::PACCommit.new("9e27dfa978004cb4845312d01c4a63da94e5f356"), #task id 5, branch master dev4
        Model::PACCommit.new("20e5168e026bb57720dddb5e94a8074d68c54748"), #task id 4, branch master dev4
        Model::PACCommit.new("4c82d62935e78f741d04e2e4b6f0e5a83f05cbfa"), #task id 100, branch master dev4
        Model::PACCommit.new("996967baae8b4cb9f862f18c31fb5d42bdd4439c"), #task id 3, branch master dev2 dev4
        Model::PACCommit.new("c533da1bc3b74c55e58f27e7ac32cf2cb19be24d"), #no task id, initial commit, branch master dev2 dev4
      ]

      pp "Checking with test asserts for un-referenced commits :"
      # Checking on unreferenced shas:
      expected_unreferenced_SHAs.each do |commit|
        assert_true(unreferenced.include?(commit), "Found a SHA in unreferenced SHAs, those without issue reference, that was not expected: #{commit.sha}")
      end
      
      not_expected_unreferenced_SHAs.each do |commit|
        assert_false(unreferenced.include?(commit), "Found a SHA in unreferenced SHAs, those without issue reference, that was not expected: #{commit.sha}")
      end
      pp "DONE - assert okay for un-referenced commits"
    end
  end # class  

  class GitTagging < Test::Unit::TestCase
    # Helper function to unzip our repo
    def unzip_file (file, destination)
      Zip::ZipFile.open(file) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
        puts "Successfully extracted"
      }
    end

    # Test setup: executed before each test
    def setup
      unzip_file("test/resources/repo_with_tags.zip", "test/resources")
    end

    # Executed after each test
    def teardown
      FileUtils.rm_rf("test/resources/repo_with_tags")
    end

    def test_get_latest_tag_function
      settings_file = File.join(File.dirname(__FILE__), '../resources/repo_with_tags_settings.yml')
      settings = YAML::load(File.open(settings_file)) 
      settings[:verbose] = 1
      Core.settings = settings
      tag_name = Core.vcs.get_latest_tag(nil)     
      #this should be 'second'
      assert_equal("second", tag_name)

      tag_first = Core.vcs.get_latest_tag "first"
      assert_equal("first", tag_first)
    end

  end # class  
end