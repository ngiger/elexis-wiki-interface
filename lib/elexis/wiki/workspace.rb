#encoding: utf-8

require 'eclipse/plugin'
require "elexis/wiki/interface"
require 'fileutils'
require 'open-uri'
require 'time'
require 'yaml'

module Elexis
  module Wiki
    class Workspace
      attr_reader :info, :views_missing_documentation, :perspectives_missing_documentation, :features_missing_documentation,
          :doc_project, :features, :info,
          :if, :wiki_url, :user, :password
      def initialize(dir, wiki = 'http://wiki.elexis.info/api.php')
        $ws_errors = []
        @wiki_url = wiki
        @if = Elexis::Wiki::Interface.new(wiki)
        @info = Eclipse::Workspace.new(dir)
        @doc_projects = Dir.glob(File.join(dir, "doc_??", ".project"))
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
                          wiki_mod  = get_image_modification_name(image)

                          if wiki_mod == nil
                            puts "first upload #{File.basename(image)} as last_git_modification is #{git_mod}" if $VERBOSE
                          else
                            to_verify = File.new(image, 'rb').read
                            got       = @if.get(File.basename(image))
                            if got == to_verify
                              puts "nothing to upload for #{image}" if $VERBOSE
                              next
                            end
                          end
                          begin
                            res = @if.upload(image, 'filename' => File.basename(image))
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
        check_config_file
        raise "must define wiki with user and password in #{@config_yml}" unless @user and @password and @wiki_url
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
        git_time = `git log -1 --pretty=format:%ai #{file}`
        return nil  unless git_time.length > 8
        Time.parse(git_time.chomp).utc
      end

      def get_page_modification_time(pagename)
        json_url = "#{@wiki_url}?action=query&format=json&prop=revisions&titles=#{pagename}&rvprop=timestamp"
        json = RestClient.get(json_url)
        wiki_json_timestamp_to_time(json, pagename)
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
        @doc_projects.each{
          |prj|
          dir = File.dirname(prj)
          get_content_from_wiki(dir, File.basename(dir))
          remove_image_files_with_id(File.basename(File.dirname(prj)), info, dir)
        } # unless defined?(RSpec)

        @info.plugins.each{
          |id, info|
            # next if not defined?(RSpec) and not /org.iatrix/i.match(id)
            puts "Pulling for plugin #{id}" if $VERBOSE
            pull_docs_views(info)
            pull_docs_plugins(info)
            pull_docs_perspectives(info)
            remove_image_files_with_id(id, info)
        }

        @info.features.each{
          |id, info|
            # next if not defined?(RSpec) and not /ehc|icp/i.match(id)
            puts "Pulling for feature #{id}" if $VERBOSE
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
        puts Dir.pwd
        res = get_content_from_wiki('.', matrix_name)
        return true if res.index("[[#{pagename}]]") or res.index("[[#{pagename}.feature.group]]")
        $ws_errors << "#{matrix_name}: could not find #{pagename}"
      end

      private
      def wiki_json_timestamp_to_time(json, page_or_img)
        return nil unless json
        begin
          m = json.match(/timestamp['"]:['"]([^'"]+)/)
          return Time.parse(m[1]) if m
        end
        nil
      end

      # http://wiki.elexis.info/api.php?action=query&format=json&list=allimages&ailimit=5&aiprop=timestamp&aiprefix=Ch.elexis.notes:config.png&*
      def get_image_modification_name(image)
        short_image = image.sub(ImagePrefix, '')
        json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aiprop=timestamp&iiprop=url&aiprefix=#{short_image}"
        json = RestClient.get(json_url)
        wiki_json_timestamp_to_time(json, image)
      end

      # helper function, as mediawiki-gateway does not handle this situation correctly
      def download_image_file(pageName, image)
        downloaded_image = File.basename(Interface.return_canonical_image_name(pageName, image))
        unless File.exist? downloaded_image
          # first search by pagename and imagename
          json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aiprefix=#{pageName}&aifrom=#{image.sub(ImagePrefix, '')}"
          json = RestClient.get(json_url)
          unless json
            puts "JSON: Could not fetch for image #{image} for #{pageName} using #{json_url}"
            return
          end
          begin
            answer = JSON.parse(json)
            image_url = nil
            image_url = answer['query'].first[1].first['url'] if answer['query'] and answer['query'].size >= 1 and answer['query'].first[1].size > 0
            unless image_url
              # as we did not find it search imagename only
              json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aifrom=#{image.sub(ImagePrefix, '')}"
              json = RestClient.get(json_url)
              if json
                answer = JSON.parse(json)
                image_url = answer['query'].first[1].first['url'] if answer['query'] and answer['query'].size >= 1 and answer['query'].first[1].size > 0
              end
            end
            if image_url
              m = /#{downloaded_image}/i.match(image_url)
              # downloaded_image = m[0] if m # Sometimes the filename is capitalized
              File.open(downloaded_image, 'w') do |file|
                file.write(open(image_url).read)
              end
              files = Dir.glob(downloaded_image, File::FNM_CASEFOLD)
              Interface.remove_image_ignoring_case(downloaded_image)
            else
              puts "skipping image #{image} for page #{pageName}"
            end
            rescue => e
              puts "JSON: Could not fetch for image #{image} for #{pageName} using #{json_url}"
              puts "      was '#{json}'"
              puts "      error was #{e.inspect}"
          end
        end
        puts "Downloaded image #{downloaded_image} #{File.size(downloaded_image)} bytes" if $VERBOSE and File.exists?(downloaded_image)
      end

      def get_content_from_wiki(out_dir, pageName)
        puts "get_content_from_wiki page #{pageName} -> #{out_dir}" if $VERBOSE
        out_name = File.join(out_dir, pageName + '.mediawiki')
        FileUtils.makedirs(out_dir) unless File.directory?(out_dir)
        savedDir = Dir.pwd
        Dir.chdir(out_dir)
        begin
          content = @if.get(pageName)
        rescue MediaWiki::Gateway::Exception => e
          puts "Unable to get #{pageName} for #{out_dir} from #{File.dirname(@if.wiki_url)}"
          return nil
        end
        if content
          ausgabe = File.open(out_name, 'w+') { |f| f.write content }
          @if.images(pageName).each{
            |image|
              download_image_file(pageName, image.gsub(' ', '_'))
              break if defined?(RSpec) and not /icpc|ehc/i.match(pageName) # speed up RSpec
          }
          Elexis::Wiki::Interface.fix_image_locations(out_name, pageName)
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
