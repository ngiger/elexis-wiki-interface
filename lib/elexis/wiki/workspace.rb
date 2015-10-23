#encoding: utf-8
require 'eclipse/plugin'
require "elexis/wiki/interface"
require "elexis/wiki/images"
require 'fileutils'
require 'open-uri'
require 'time'
require 'yaml'

module Elexis
  module Wiki
    class Workspace
      TestPattern = /[\._]test[s]*$/i
      attr_reader :info, :views_missing_documentation, :perspectives_missing_documentation, :features_missing_documentation,
          :ws_dir, :doc_project, :features, :info,
          :if, :wiki_url, :user, :password
      def initialize(dir, wiki = nil)
        $stdout.sync = true
        @if = Elexis::Wiki::Interface.new(wiki)
        raise "must define wiki with user and password in #{@config_yml}" unless @if.user and @if.password and @if.wiki_url
        $ws_errors = []
        @info = Eclipse::Workspace.new(dir)
        @doc_projects = Dir.glob(File.join(dir, "doc_??", ".project"))
        @ws_dir = dir
        @info.parse_sub_dirs
        @info.show if $VERBOSE
        @views_missing_documentation        =[]
        @perspectives_missing_documentation =[]
        @features_missing_documentation     =[]
      end

      def show_missing(details = false)
        puts
        msg  = "Show errors for #{@info.workspace_dir}"
        puts "-" * msg.size
        puts msg
        puts "-" * msg.size

        if views_missing_documentation.size and
            features_missing_documentation.size == 0 and
            perspectives_missing_documentation.size == 0
          puts "Eclipse-Workspace #{@info.workspace_dir} seems to have documented all views, features, plugins and perspectives"
        else
          puts "Eclipse-Workspace #{@info.workspace_dir} needs documenting "
          if views_missing_documentation.size > 0
            puts "  #{views_missing_documentation.size} views"
            puts "    #{views_missing_documentation.inspect}" if details
          end
          if features_missing_documentation.size > 0
            puts "  #{features_missing_documentation.size} features"
            puts "    #{features_missing_documentation.inspect}" if details
          end
          if perspectives_missing_documentation.size > 0
            puts "  #{perspectives_missing_documentation.size} perspectives"
            puts "    #{perspectives_missing_documentation.inspect}" if details
          end
        end
        puts $ws_errors
        puts "Displayed #{$ws_errors.size} errors"
      end
      def push_doc_dir(id, docDir = nil)
        docDir  ||= File.join(@info.workspace_dir, id, 'doc')
        to_push = Dir.glob("#{docDir}/*.mediawiki")
        to_push.each{
              |file|
              # verify that locally committed file is newer than the page in the wiki
              # verify that the content after the push matches the local content
              my_new_content = File.new(file).read
              to_verify = my_new_content.gsub(/\n+/,"\n").chomp
              pagename = File.basename(file, '.mediawiki').capitalize
              last_wiki_modification = get_page_modification_time(pagename)
              last_git_modification = get_git_modification(file)
              unless last_wiki_modification
                puts "first upload #{File.basename(file)} last_git_modification is #{last_git_modification}" if $VERBOSE
                @if.create(pagename, my_new_content,{:overwrite => true, :summary => "pushed by #{File.basename(__FILE__)}" })
              else
                got = @if.get(pagename).gsub(/\n+/,"\n")
                if got == to_verify
                  puts "No changes to push for #{file}"
                  next
                end
                @if.edit(pagename, to_verify,{:overwrite => true, :summary => "pushed by #{File.basename(__FILE__)}" })
                puts "Uploaded #{file} to #{pagename}" # if $VERBOSE
              end
          }
        if to_push.size > 0 # then upload also all *.png files
          images_to_push = Dir.glob("#{docDir}/*.png")
          images_to_push.each{
                            |image|
                          if /:/.match(File.basename(image))
                              puts "You may not add a file containg ':' or it will break git for Windows. Remove/rename #{image}"
                              exit
                          end

                          git_mod   = get_git_modification(image)
                          wiki_mod  = @if.get_image_modification_name(File.basename(image))

                          if wiki_mod == nil
                            puts "first upload #{File.basename(image)} as last_git_modification is #{git_mod}" if $VERBOSE
                          else
                            to_verify = File.new(image, 'rb').read
                            got       = @if.download_image_file(File.basename(image))
                            if got and got == to_verify
                              puts "nothing to upload for #{image}" if $VERBOSE
                              next
                            end
                          end
                          begin
                            res = @if.upload(File.basename(image), image)
                            puts "res für #{image}  exists? #{File.exists?(image)} ist #{res.to_s}" if $VERBOSE
                          rescue MediaWiki::APIError => e
                            puts "rescue für #{image} #{e}" #  if $VERBOSE
                            if /verification-error/.match(e.to_s)
                              puts "If you received API error: code 'verification-error', info 'This file did not pass file verification'"
                              puts "this means that the file type and content do not match, e.g. you have a *png file but in reality it is a JPEG file."
                              puts "In this case convert file.png file.png fixes this problem"
                            end
                          end
          }
        end
      end
      def push
        @doc_projects.each{
          |prj|
          dir = File.dirname(prj)
          push_doc_dir(File.basename(dir), dir)
        }
        @info.features.each{ |id, info|  push_doc_dir(id) }
        @info.plugins.each{  |id,plugin| push_doc_dir(id) }
      end

      def get_git_modification(file)
        return nil unless File.exists?(file)
        git_time = `git log -1 --pretty=format:%ai '#{file}'`
        return nil  unless git_time.length > 8
        Time.parse(git_time.chomp).utc
      end

      def get_page_modification_time(pagename)
        json_url = "#{@if.wiki_url}?action=query&format=json&prop=revisions&titles=#{pagename}&rvprop=timestamp"
        json = RestClient.get(json_url)
        @if.wiki_json_timestamp_to_time(json, pagename)
      end

      def remove_image_files_with_id(id, info, docDir = nil)
        docDir ||= File.join(@info.workspace_dir, id, 'doc')
        files = Dir.glob(File.join(docDir, "#{id}_*jpg"), File::FNM_CASEFOLD) +
            Dir.glob(File.join(docDir, "#{id}_*gif"), File::FNM_CASEFOLD) +
            Dir.glob(File.join(docDir, "#{id}_*png"), File::FNM_CASEFOLD)
        system("git rm #{files.join(' ')}") if files.size > 0
      end

      def pull
        savedDir = Dir.pwd
        idx = 0
        @doc_projects.each{
          |prj|
          puts "#{@if.wiki_url} Pulling for doc_project nr #{idx}: #{prj}" if (idx % 10) == 0
          idx += 1
          dir = File.dirname(prj)
          get_content_from_wiki(dir, File.basename(dir))
          remove_image_files_with_id(File.basename(File.dirname(prj)), info, dir)
        } # unless defined?(RSpec)

        idx = 0
        @info.plugins.each{
          |id, info|
            # next if not defined?(RSpec) and not /org.iatrix/i.match(id)
            puts "#{@if.wiki_url} Pulling for plugin nr #{idx}: #{id}" if (idx % 10) == 0
            idx += 1
            pull_docs_views(info)
            pull_docs_plugins(info)
            pull_docs_perspectives(info)
            remove_image_files_with_id(id, info)
        }

        idx = 0
        @info.features.each{
          |id, info|
            # next if not defined?(RSpec) and not /ehc|icp/i.match(id)
            puts "#{@if.wiki_url} Pulling for feature nr #{idx}: #{id}" if (idx % 10) == 0
            idx += 1
            check_page_in_matrix(id)
            pull_docs_features(info)
            remove_image_files_with_id(id, info)
        }

        Dir.chdir(savedDir)
      end

      def perspectiveToPageName(perspective)
        # http://wiki.elexis.info/P_Abrechnungen
        name = 'P_'+ perspective.id.gsub(' ', '')
        puts "perspectiveToPageName for #{perspective.inspect} is '#{name}'" if $VERBOSE
        name
      end
      def viewToPageName(plugin_id, view)
        # für ch.elexis.agenda.views.TagesView (= view.id)
        # http://wiki.elexis.info/ChElexisAgendaViewsTagesview
        # wurde unter http://wiki.elexis.info/Hauptseite ein Link Agenda (= view.name) angelegt.
        # evtl. sollten wir testen, ob dieser Link vorhanden ist
        # http://wiki.elexis.info/ChElexisIcpcViewsEpisodesview
        comps = view.id.split('.')
        pageName = comps[0..-2].collect{|x| x.capitalize}.join + 'Views'+view.id.split('.').last.capitalize
        puts "viewToPageName for #{plugin_id}/#{view.id} is #{pageName}" if $VERBOSE
        pageName
      end

      def check_page_in_matrix(pagename, matrix_name = 'Matrix_3.0')
        savedDir = Dir.pwd
        Dir.chdir(@ws_dir)
        res = get_content_from_wiki('.', matrix_name)
        return true if res.index("[[#{pagename}]]") or res.index("[[#{pagename}.feature.group]]")
        $ws_errors << "#{matrix_name}: could not find #{pagename}"
        Dir.chdir(savedDir)
      end

      private
      def get_content_from_wiki(out_dir, pageName)
        puts "get_content_from_wiki page #{pageName} -> #{out_dir}" if $VERBOSE
        out_name = File.join(out_dir, pageName + '.mediawiki')
        FileUtils.makedirs(out_dir) unless File.directory?(out_dir)
        savedDir = Dir.pwd
        Dir.chdir(out_dir)
        begin
          content = @if.get(pageName)
        rescue
          puts "Unable to get #{pageName} for #{out_dir} from #{@if.wiki_url ? File.dirname(@if.wiki_url): 'nil'}"
          return nil
        end
        if content
          ausgabe = File.open(out_name, 'w+') { |f| f.write content }
          images = @if.images(pageName)
          images.each{
            |image|
              image_name = File.basename(image)
              m = Wiki::ImagePattern.match(image_name)
              image_name = m[2] if m and not image_name.index('-')
              begin
                  @if.download_image_file(image_name, image_name, pageName)
              rescue => e
                msg = "Failed download #{image_name}"
                puts msg
                $ws_errors << msg
              end
              break if defined?(RSpec) and not /matrix|icpc|ehc/i.match(pageName) # speed up RSpec
          }
        else
          puts "Could not fetch #{pageName} from #{@if}" if $VERBOSE
        end
        Dir.chdir(savedDir)
        content
      end
      def pull_docs_views(plugin)
        id = plugin.symbolicName
        plugin.views.each{
          |id, view|
          pageName = viewToPageName(plugin.symbolicName, view)
          content = get_content_from_wiki(File.join(@info.workspace_dir, File.basename(plugin.jar_or_src), 'doc'), pageName)
          next if TestPattern.match(id)
          @views_missing_documentation << pageName unless content
        }
      end
      def pull_docs_perspectives(plugin)
        id = plugin.symbolicName
        plugin.perspectives.each{
          |id, perspective|
          pageName = perspectiveToPageName(perspective)
          content = get_content_from_wiki(File.join(@info.workspace_dir, File.basename(plugin.jar_or_src), 'doc'), pageName)
          next if TestPattern.match(id)
          @perspectives_missing_documentation << pageName unless content
        }
      end
      def pull_docs_plugins(plugin)
        id = plugin.symbolicName
        pageName = id.capitalize
        content = get_content_from_wiki(File.join(@info.workspace_dir, File.basename(plugin.jar_or_src), 'doc'), pageName)
        return if TestPattern.match(id)
      end
      def pull_docs_features(feature)
        id = feature.symbolicName
        pageName = id.capitalize
        content = get_content_from_wiki(File.join(@info.workspace_dir, id, 'doc'), pageName)
        unless content
          content = get_content_from_wiki(File.join(@info.workspace_dir, id, 'doc'), pageName.sub(/feature$/, 'feature.feature.group'))
          puts "pull_docs_features failed #{id} #{pageName}" unless content
        end
      end
    end
  end
end
