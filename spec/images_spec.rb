#encoding : utf-8
require 'spec_helper'

require "elexis/wiki/images"

describe 'Images' do
  NR_PICTURES = 23

  before :all do
    @subdir = 'images'
    @originDir = File.expand_path(File.join(File.dirname(__FILE__), 'data', @subdir))
    @dataDir = File.expand_path(File.join(File.dirname(__FILE__), 'run', @subdir))
    FileUtils.rm_rf(@dataDir)
    FileUtils.makedirs(@dataDir)
    FileUtils.cp_r(@originDir, @dataDir, :preserve => true)
    @images = Elexis::Wiki::Images.new(@dataDir)
  end

  after :all do
#    FileUtils.rm_rf(@dataDir)
  end

  it "should create the pictures.yml and .csv file" do
    expect(@images.yml).to eq File.join(@images.rootDir, 'pictures.yml')
    expect(@images.csv).to eq File.join(@images.rootDir, 'pictures.csv')
    expect(File.exist?(@images.yml)).to eq true
    expect(File.exist?(@images.csv)).to eq true
  end


  it "should read #{NR_PICTURES} pictures" do
    expect(@images.pictures.size).to eq NR_PICTURES
  end

  it "pictures.yml should contain some png" do
    content = IO.read(@images.yml)
    expect(content.index('doc/ch.elexis.icpc_icpc1.png')).not_to eq 0
    expect(content.index('doc/icpc1.png')).not_to eq 0
    expect(content.index('icpc6.png')).not_to eq 0
    expect(content.index('favicon_green.png')).not_to eq 0
  end

  it "pictures.csv should contain some png" do
    content = IO.read(@images.csv)
    expect(content.index('icpc6.png')).not_to eq 0
    expect(content.index('favicon_green.png')).not_to eq 0
  end

  def check_rename(wiki_file, old_picture_name, new_picture_name, expected_new_line)
    expect(IO.read(wiki_file)).to include old_picture_name
    @images.change_image_name_in_mediawiki(wiki_file, old_picture_name, new_picture_name)
    changed = IO.read(wiki_file)
    expect(changed).to include "tag_one"
    expect(changed).to include "tag_two"
    expect(changed).to include "tag_three"
    changed.index(new_picture_name)
    expect(changed).to include expected_new_line
  end

  describe 'get_name_with_project' do
    tests = {
      'elexis-3-base/ch.elexis.connect.reflotron.v2/doc/test.png' => 'reflotron-test.png',
      'elexis-3-base/ch.elexis.connect.reflotron.v2.feature/doc/test.png' => 'reflotron-test.png',
      'elexis-3-base/ch.elexis.laborimport.viollier.v2_test/doc/test.png' => 'viollier-test.png',
      'org.iatrix/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.test/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.feature/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.tests/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.tests/doc/test.jpg' => 'iatrix-test.jpg',
      'org.iatrix_tests/doc/test.gif' => 'iatrix-test.gif',
      }
    tests.each {
      |path, expected|
      it "should return #{expected} for #{path}" do
        value = @images.get_name_with_project(path)
        expect(value).to eq expected
      end
    }
  end

  rename_tests = {
     'Ch.elexis.icpc:icpc5.png' => [ 'icpc5.png', 'tag_png [[File:icpc5.png|image]]'],
     'Ch.elexis.icpc:icpc6.png' => [ 'elexis_logo.jpg', 'tag_jpg [[File:elexis_logo.jpg|image]]'],
     'Ch.elexis.icpc:icpc7.png' => [ 'disposan.gif', 'tag_gif [[File:disposan.gif|image]]'],
    }
  rename_tests.each {
              |old_picture_name, params|
    it "should go work with #{params[1]}" do
      full_name =  File.join(@dataDir, @subdir, 'ch.elexis.icpc', 'doc', 'test2.mediawiki')
      check_rename(full_name, old_picture_name, params[0], params[1])
    end
  }

  it "should refuse to change the image name in a mediawiki file when we find no corresponding image file" do
    wiki_file = File.join(@dataDir, @subdir, 'ch.elexis.icpc', 'doc', 'test2.mediawiki')
    expect(File.exist?(wiki_file)).to eq true
    old_picture_name = 'ch.elexis.icpc:icpc4.png'
    expect(IO.read(wiki_file)).to include old_picture_name
    expect { @images.change_image_name_in_mediawiki(wiki_file, old_picture_name, 'icpc_should_not_exist.png')}.to raise_error(RuntimeError, /Could not find image/)
  end

  describe "determine_cleanup" do
    before(:all) do
      @images.determine_cleanup
    end

    it "should find duplicates" do
      expect(@images.duplicates.size).not_to eq 0
    end

    it "should find nr_single_sha" do
      expect(@images.nr_single_sha.size).not_to eq 0
    end

    it "should find to_short_names" do
      expect(@images.to_short_names.size).not_to eq 0
    end

    # now the failing ones
    it "should find same_name_but_differen_content" do
      # skip "No example yet"
      expect(@images.dup_non_identical.size).not_to eq 0
    end

    it "should find multiple_names" do
      expect(@images.multiple_names.size).not_to eq 0
    end
    it "should find short_and_sha_okay" do
      expect(@images.short_and_sha_okay.size).not_to eq 0
    end

    it "should find wrong_best_name" do
      expect(@images.wrong_best_name.size).to eq 0
    end

    it "should find new_best_name" do
      expect(@images.new_best_name.size).not_to eq 0
    end
  end
end


describe 'ImagesCleanup' do

  def setup_run
    @subdir = 'images'
    @originDir = File.expand_path(File.join(File.dirname(__FILE__), 'data', @subdir))
    @dataDir = File.expand_path(File.join(File.dirname(__FILE__), 'run', @subdir))
    FileUtils.rm_rf(@dataDir)
    FileUtils.makedirs(@dataDir)
    FileUtils.cp_r(@originDir, @dataDir, :preserve => true)
    @images = Elexis::Wiki::Images.new(@dataDir)
  end

  before :all do
    setup_run
  end

  describe "execute_cleanup with git" do
    before(:all) do
      setup_run
      system("git init #{@dataDir}")
      @images.determine_cleanup
      @images.execute_cleanup(true)
    end

    it "should add Icpc8.png and icpc1.png" do
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/icpc1.png")).not_to eq nil
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/Icpc8.png")).not_to eq nil
    end
  end

  describe "execute_cleanup" do
    before(:all) do
      setup_run
      @images.determine_cleanup
      @images.execute_cleanup
    end

    it "should change_image_name_in_mediawiki" do
      cmd = 'change_image_name_in_mediawiki test.mediawiki kabel.png icpc-kabel.png'
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should remove obsolete symlinks" do
      cmd = 'rm Ch.elexis.notes'
      expect(@images.actions.index(cmd) >= 0)
    end


    it "should NOT mv medevit_inbox1.png" do
      cmd = 'medevit_inbox1.png'
      expect(@images.actions.index(cmd)).to eq nil
    end

    it "should mv Com.hilotec.elexis.opendocument_anleitung_opendocument_1.png to anleitung_opendocument_1.png" do
      cmd = 'mv Com.hilotec.elexis.opendocument_anleitung_opendocument_1.png anleitung_opendocument_1.png'
      puts @images.actions.join("\n")
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should find mv duplicate-images" do
      cmd = 'mv kabel.png icpc-kabel.png'
      expect(@images.actions.index(cmd) >= 0)
      @images.execute_cleanup
      cmd = 'mv kabel.png icpc-kabel.png'
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should find remove old files" do
      cmd = 'rm -f ch.elexis.icpc_icpc1.png'
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should find any files with ':' in their names" do
      search = "#{@images.rootDir}/**/*:*"
      files = Dir.glob(search)
      expect(files.size).to eq 0
    end
    it "should remove_files_with_case_sensitive_changes" do
      lowercase = "#{@images.rootDir}/test_lower_case.png"
      up_case = "#{@images.rootDir}/TEST_LOWER_CASE.png"
      capitalized = "#{@images.rootDir}/Test_lower_case.png"
      [ lowercase, up_case, capitalized].each {
        |file|
          system("touch #{file}")
          expect(File.exist?(file))
      }
      @images.remove_files_with_case_sensitive_changes(lowercase)
      expect(File.exist?(lowercase))
      expect(File.exist?(up_case)).to eq false
      expect(File.exist?(capitalized)).to eq false
    end
  end
end

