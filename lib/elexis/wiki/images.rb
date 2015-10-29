#encoding: utf-8

require 'eclipse/plugin'
require 'media_wiki'
require 'mediawiki_api'
require 'elexis/wiki/images'
require 'fileutils'
require 'open-uri'
require 'time'
require 'yaml'
require 'csv'

class String
  # Convert CamelCase to underscore
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    downcase
  end
end

module Elexis
  module Wiki
    ImageWithSlashPattern = /(\[File:|Datei:|\[Image:)([^\/:\]]*[:\/])([\w.-]+)/
    ImagePattern = /(\[File:|\[Datei:|\[Image:)((?:.+:|)[^\/:|]*)/

    #
    # This helper class collect information about all images used in
    # subdirectories doc ending with mediawiki and stores the results
    # in a pictures.yml and a pictures.csv file
    #
    # Several helper allow showing unused pictures, identifying
    # files with same name, but different content and pictures use
    # in several sub-directories
    #
    class Images

      private
        def write_yml_and_csv
          File.open(@yml, 'w+') {|f| f.puts @pictures.to_yaml}
          column_header = ["sha256","name","project","path"]
          CSV.open(csv, 'w+',
                   :write_headers=> true,
                   :headers => column_header
                  ) do |csv|
                csv << ["# Generated by: #{File.basename(__FILE__)} at #{Time.now.utc}"]
                @pictures.each{ |pict| csv << pict.values.to_a  }
          end
        end
        def initialize_database
          savedDir = Dir.pwd
          Dir.chdir(@rootDir)
          @docs = Dir.glob('**/doc').reject{|x| x.match(/(^vendor|\/vendor)\//) } # doc_fr is mostly a duplicate of doc_de
          @docs.each{
            |doc_dir|
            pngs = Dir.glob("#{doc_dir}/**/*.{png,jpg}", File::FNM_CASEFOLD)
            puts "#{doc_dir} has #{pngs.size} png" if $VERBOSE
            next if pngs.size == 0
            pngs.each {
                      |png|
                      if File.size(png) == 0
                        FileUtils.rm_f(png, :verbose => true)
                        next
                      end
                      sha256 = Digest::SHA256.hexdigest(IO.read(png))
                      pict = { :sha256 => sha256,
                               :name => File.basename(png),
                               :project => File.basename(File.dirname(File.dirname(png))),
                               :path => png}
                      @pictures << pict
                      }
            # break if pngs.size > 1
          }
          @sha_2_png = {}
          @pictures.uniq! { |elem| elem[:path].downcase }
          @pictures.each {
            |picture|
            if @sha_2_png[picture[:sha256]]
              @sha_2_png[picture[:sha256]] << picture
            else
              @sha_2_png[picture[:sha256]] = [picture]
            end
          }
          @duplicates        = @sha_2_png.find_all{|sha, list| list.size > 1}
          write_yml_and_csv
        ensure
          Dir.chdir(savedDir)
        end

        def verify_best_name(picture)
          if picture[:best_name]
            wrong_best_name = @pictures.find_all{|x| x[:best_name] == picture[:best_name] and x[:sha256] != picture[:sha256]}
            if wrong_best_name.size > 0
              puts "   #{wrong_best_name.size} entries #{wrong_best_name}" #if $VERBOSE
              @wrong_best_name << [picture[:path], wrong_best_name.collect{|x| x[:path]} ]
              new_name = get_name_with_project(picture[:path])
              if picture[:best_name] != new_name
                puts "new_best_name 2 is #{new_name} for #{picture[:path]}" #if $VERBOSE
                picture[:rule] += " name get_name_with_project"
                picture[:best_name] = new_name
              else
                @@uniq_id ||= 0
                new_name = '27'
                begin
                  @@uniq_id += 1
                  new_name = File.dirname(picture[:path]) + "/#{@@uniq_id}_" + picture[:name]
                end until File.exist?(new_name).eql?(false)
                puts "new_best_name 3 is #{new_name} for #{picture[:path]}" # if $VERBOSE
                picture[:rule] += " third #{new_name}"
                picture[:best_name] = File.basename(new_name)
              end
            end
          end
        end

        def set_best_name(picture)
          debug = $VERBOSE
          path = picture[:path]
          sha256 = Digest::SHA256.hexdigest(IO.read(path))
          same_sha256 = @pictures.find_all{|x| x[:sha256] == sha256}
          same_name   = @pictures.find_all{|x| x[:name] == picture[:name]}
          nrSha256 = same_name.collect{|c| Images.get_small_name(c[:sha256])}.uniq
          if same_sha256.size == 1 and nrSha256.size == 1
            puts "new_best_name 3 @short_and_sha_okay #{sha256} for #{path}" if debug
            picture[:rule] = 'short_and_sha_okay nr_single_sha'
            @short_and_sha_okay << path
            @nr_single_sha << same_sha256
            picture[:best_name] = Images.get_small_name(path)
            return
          else
            msg = " nrSha #{sha256.size} #{sha256}"
            if same_sha256.collect{|c| c[:name]}.uniq.size == 1 and nrSha256.size == 1
              puts "@short_and_sha_okay #{path} sha256 #{sha256} for #{same_sha256.size} files" if debug
              picture[:rule] = 'short_and_sha_okay'
              @short_and_sha_okay << path
              return
            end
            found = same_sha256.collect{|c| c[:name].downcase}.uniq
            if found.size == 1  and nrSha256.size == 1
              puts "new_best_name 4 case_sensitives #{found}" if debug
              picture[:rule] = 'case_sensitives'
              picture[:best_name] = Images.get_small_name(path)
              return
            end
            multiple = same_sha256.collect{|c| c[:name]}.uniq
            to_reduce = same_sha256.collect{|c| Images.get_small_name(c[:name])}.uniq
            if nrSha256.size == 1
              @to_short_names[path] = to_reduce
              puts "new_best_name 5 to_short_names #{multiple} =>  #{to_reduce} nrSha #{sha256.size} #{sha256}" if debug
              picture[:rule] = 'to_short_names'
              picture[:best_name] = Images.get_small_name(path)
              return
            end
            puts "new_best_name  6 multiple #{multiple} to_reduce #{to_reduce} #{get_name_with_project(picture[:path])}" if debug
            @multiple_names[path] = same_sha256
            picture[:best_name] =  get_name_with_project(picture[:path])
            picture[:rule] = 'multiple_names'
            return
          end
        end
      public
      attr_reader :rootDir, :docDir, :extension, :yml, :csv, :pictures, :sha_2_png,
          :multiple_names, :to_short_names, :nr_single_sha,
          :short_and_sha_okay,  :wrong_best_name, :new_best_name,
          :duplicates, :dup_non_identical, :actions

      def initialize(rootDir = Dir.pwd, docDir = 'doc', extension = '.mediawiki')
        @rootDir            = rootDir
        @docDir             = docDir
        @extension          = extension
        @add_changes_to_git = false
        @pictures           = []
        @multiple_names     = {}
        @to_short_names     = {}
        @nr_single_sha      = []
        @short_and_sha_okay = []
        @wrong_best_name    = []
        @new_best_name      = {}
        @yml                = File.expand_path(File.join(@rootDir, 'pictures.yml'))
        @csv                = File.expand_path(File.join(@rootDir, 'pictures.csv'))
        initialize_database
      end

      def Images.get_project_abbreviation(path)
        dir = File.dirname(path)
        dir.sub!(/\/images$/, '')
        found = dir.sub(/(\.feature|[._]test.*|)\/doc/i, '').sub(/\.v\d$/, '')
        found.split('.')[-1]
      end

      def get_name_with_project(path)
        prefix =Images.get_project_abbreviation(path)
        basename = File.basename(path)
        result = /^#{prefix}/i.match(basename) ? basename : (prefix + '-' + basename).gsub(':', '-')
        result.downcase
      end

      def Images.get_small_name(path)
        ext =  File.extname(path)
        to_consider = File.basename(path, ext).gsub(':','-').underscore
        if to_consider.index('.')
          part = to_consider.split('.')[-1].downcase
          if  part.split('_').size > 1
            result = part.split('_')[1..-1].join('_')
          else
            result = part
          end
        else
          result = to_consider
        end
        short = Images.get_project_abbreviation(path)
        regexp = /^(#{short})([^-])/i
        m = regexp.match(result)
        result = result.sub(regexp, '\1-\2') if m and short
        (result + ext).downcase
      end

      def determine_cleanup
        savedDir = Dir.pwd
        Dir.chdir(@rootDir)
        @pictures.each{ |picture| set_best_name(picture) }
        @pictures.each{ |picture| verify_best_name(picture) }
        @wrong_best_name = []
        @pictures.each{ |picture| verify_best_name(picture) }
        @dup_non_identical = @pictures.collect{ |p| p[:path] if p[:rule] =~ /multiple/}.compact
        @pictures.find{ |outer| @pictures.find_all{ |inner| inner[:name].eql?(outer[:name]) and not inner[:sha256].eql?(outer[:sha256])}.size > 1 }
        @new_best_name     = @pictures.find_all{ |picture| picture[:best_name] and not picture[:best_name].downcase.eql?(picture[:name].downcase) }
        write_yml_and_csv
      ensure
        Dir.chdir(savedDir)
      end

      def remove_obsolete_symlinks
        @docs.each do
          |docDir|
          Dir.chdir(File.join(@rootDir, docDir))
          project =  File.basename(File.dirname(docDir))
          tries = [project, project.capitalize, project.sub('.feature', ''), project.sub('.feature', '').capitalize]
          files = []
          tries.each{|try| files << try if File.symlink?(try) }
          files.compact.each do
            |symlink|
            if symlink and File.symlink?(symlink)
                cmd = "rm #{symlink}"
                @actions << cmd
                FileUtils.rm_f(symlink, :verbose => true)
                run_git_cmd("git rm -f --ignore-unmatch #{symlink}") if @add_changes_to_git
            end
          end
        end
      end

      def run_git_cmd(git_cmd, may_fail=false)
        return unless @add_changes_to_git
        res = system(git_cmd)
        unless res
          raise "Running #{git_cmd} failed"
        end unless may_fail
        @actions  << git_cmd
      end

      def execute_cleanup(add_changes_to_git=false)
        @add_changes_to_git = add_changes_to_git
        @actions ||= []
        savedDir = Dir.pwd
        remove_obsolete_symlinks
        Dir.chdir(@rootDir)
        cmds = []
        @new_best_name.each{
          |picture|
          dir_name = File.dirname(picture[:path])
          Dir.chdir(File.join(@rootDir, dir_name))
          Dir.glob("*#{extension}").each  do
            |wiki_file|
          old_image_name = picture[:name]
          new_image_name = picture[:best_name].downcase
          if old_image_name.index('-')
            puts "Skipping mv #{old_image_name} #{new_image_name}"
            next
          end
          cmd = "change_image_name_in_mediawiki #{wiki_file} #{picture[:name]} #{picture[:best_name]}"
          # cmd = 'change_image_name_in_mediawiki test.mediawiki ch.elexis.icpc_icpc1.png icpc1.png'
          change_image_name_in_mediawiki wiki_file, old_image_name, new_image_name
          @actions  << cmd
          oldFiles = Dir.glob(old_image_name, File::FNM_CASEFOLD)
          oldFiles.each{ |old_file|
                        if @add_changes_to_git
                          run_git_cmd("git rm -f --ignore-unmatch #{old_file}") if File.exist?(old_file)
                        else
                          FileUtils.rm_f(old_file, :verbose => true)
                          @actions  << "rm -f #{old_file}"
                        end
                       }
        end
        }

        # change_image_name_in_mediawiki
        Dir.chdir(@rootDir)
        # Add all pictures which were downloaded and still have the same name
        @pictures.each { |picture|
                          next unless picture[:best_name]
                          dir = File.dirname(picture[:path])
                          dir ||= '.'
                          new_path = File.join(dir, picture[:best_name])
                          next unless File.exists?(picture[:path])
                          FileUtils.cp(picture[:path], new_path, :verbose => true)  unless File.exists?(new_path)
                          run_git_cmd("git add -f #{new_path}")
                          run_git_cmd("git rm -f --ignore-unmatch #{picture[:path]}", true) if picture[:path] != new_path
                         }
        @actions.uniq!
        cleanup_mediawikis
        puts @actions.join("\n")
      ensure
        Dir.chdir(savedDir)
      end

      # Helper for scripts
      # We assume that the referenced new_image_name is living in the same directory
      # as the mediawiki_file
      def change_image_name_in_mediawiki(mediawiki_file, old_image_name, new_image_name)
        savedDir = Dir.pwd
        Dir.chdir(File.dirname(mediawiki_file))
        if new_image_name.downcase != File.basename(new_image_name).downcase
          raise "new_image_name #{new_image_name} may not contain a directory path"
        end
        if @add_changes_to_git
          run_git_cmd("git add #{old_image_name} && git mv #{old_image_name} #{new_image_name}")
        elsif @actions
          @actions << "mv #{old_image_name} #{new_image_name}"
          FileUtils.mv(old_image_name, new_image_name, :verbose => true)
        end unless File.exists?(new_image_name)
        puts "change_image_name_in_mediawiki #{Dir.pwd}/#{mediawiki_file}: #{old_image_name.inspect} => #{new_image_name.inspect}" # if $VERBOSE
        newLines = []
        lines = IO.readlines(mediawiki_file)
        lines.each{
          |line|
          image_name = nil
          if m = ImageWithSlashPattern.match(line)
            image_name = m[2] + m[3]
          elsif m = ImagePattern.match(line)
            image_name = m[2]
          end
          unless image_name
            newLines << fix_line(line)
            next;
          end
          if old_image_name.downcase.eql?(image_name.downcase) or/\/#{old_image_name}/i.match(image_name)
              dirName = File.dirname(mediawiki_file)
              simpleName = File.join(dirName, File.basename(new_image_name))
              raise "Could not find image" unless File.exists?(new_image_name)
              if files = Dir.glob(simpleName, File::FNM_CASEFOLD) and files.size >= 1
                newLines << fix_line(line, old_image_name, new_image_name)
              else
                newLines << fix_line(line)
              end
          else
            newLines << fix_line(line)
          end
        }
        File.open(mediawiki_file, "w") {|f| f.write newLines.join.gsub(/\[\[Datei:|\[\[Image:/i, '[[File:')}
        run_git_cmd("git add #{mediawiki_file}")
      ensure Dir.chdir(savedDir)
      end
      def fix_line(line, old_file=nil, new_file=nil)
        line.gsub!(/(<U\+\h\h\h\h>)/,'') # remove pseudo UTF-8
        old_ref = 'unknown'
        unless old_file
          image_name = nil
          if m = ImageWithSlashPattern.match(line)
            old_file = m[2] + m[3]
            old_ref = m[3].downcase
          elsif m = ImagePattern.match(line)
            old_file = m[2]
            old_ref = m[2].downcase
          end
          return line unless m
        end
        new_file ||= Images.get_small_name(old_file)
        proj = Images.get_project_abbreviation(Dir.pwd)
        change_to = nil
        if File.exists?(new_file)
          change_to ||= new_file
        else
          [ old_ref,
            old_file.sub(/^#{proj}[_]/i, proj+'-'),
            new_file.sub(/^#{proj}/i, ''),
            proj + '-' + new_file.sub(/^#{proj}/i, ''),
            new_file.sub(/^#{proj}-#{proj}/i, proj + '-'),
            new_file.sub(/^#{proj}-(.*)/i, proj + '\1'),
            (proj + '-' + new_file).downcase,
            ].each{
              |try_this|
              if File.exists?(try_this.downcase)
                change_to ||= try_this.downcase
                break
              end
            }
        end
        return line unless change_to
        line.sub(old_file, change_to)
      end

      def cleanup_mediawikis
        savedDir = Dir.pwd
        @docs.each do
          |docDir|
          Dir.chdir(File.join(@rootDir, docDir))
            wikis = Dir.glob('*.mediawiki')
            wikis.each{
              |file|
              output = ''
              lines = IO.readlines(file)
              lines.each{|line| output << fix_line(line) }
              File.open(file, 'w+') { |f| f.write(output) }
            }
        end
        ensure
          Dir.chdir(savedDir)
      end

    end
  end
end
