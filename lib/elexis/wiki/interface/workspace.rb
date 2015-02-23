#encoding: utf-8

require 'eclipse/plugin'
require 'media_wiki'
require 'fileutils'
require 'open-uri'
require 'time'
require 'yaml'

module Elexis
  module Wiki
    module Interface
      class Workspace
        attr_reader :info, :mw, :wiki, :views_missing_documentation, :perspectives_missing_documentation, :plugins_missing_documentation, :features_missing_documentation,
            :doc_project, :features, :info
        def initialize(dir, wiki = 'http://wiki.elexis.info/api.php')
          @wiki = wiki
          @mw = MediaWiki::Gateway.new(@wiki)
          @info = Eclipse::Workspace.new(dir)
          @doc_projects = Dir.glob(File.join(dir, "doc_??", ".project"))
          @info.parse_sub_dirs
          @info.show if $VERBOSE
          @views_missing_documentation        =[]
          @perspectives_missing_documentation =[]
          @plugins_missing_documentation      =[]
          @features_missing_documentation     =[]
        end
        def show_missing(details = false)
          if views_missing_documentation.size and
              plugins_missing_documentation.size == 0 and
              features_missing_documentation.size == 0 and
              perspectives_missing_documentation.size == 0
            puts "Eclipse-Workspace #{@info.workspace_dir} seems to have documented all views, features, plugins and perspectives"
          else
            puts "Eclipse-Workspace #{@info.workspace_dir} needs documenting "
            if views_missing_documentation.size > 0
              puts "  #{views_missing_documentation.size} views"
              puts "    #{views_missing_documentation.inspect}" if details
            end
            if plugins_missing_documentation.size > 0
              puts "  #{plugins_missing_documentation.size} plugins"
              puts "    #{plugins_missing_documentation.inspect}" if details
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
        end
        def push
          check_config_file
          raise "must define wiki with user and password in #{@config_yml}" unless @user and @password and @wiki
          @mw.login(@user, @password)
          @doc_projects.each{
            |prj|
            dir = File.dirname(prj)
          }
          @info.plugins.each{
            |id,plugin|
              to_push = Dir.glob("#{plugin.jar_or_src}/doc/*.mediawiki")
              to_push.each{
                           |file|
                            # verify that locally committed file is newer than the page in the wiki
                            # verify that the content after the push matches the local content
                            my_new_content = File.new(file).read
                            to_verify = my_new_content.gsub(/\n+/,"\n").chomp
                            pagename = File.basename(file, '.mediawiki').capitalize
                            last_wiki_modification = get_page_modification_time(pagename)
                            last_git_modification = get_git_modification(file)
                            puts "upload #{File.basename(file)} #{last_git_modification > last_wiki_modification} as last_git_modification is #{last_git_modification} last_wiki_modification was #{last_wiki_modification}" if $VERBOSE
                            next last_git_modification > last_wiki_modification
                            @mw.create(pagename, my_new_content,{:overwrite => true, :summary => "pushed by #{File.basename(__FILE__)}" })
                            got = @mw.get(pagename).gsub(/\n+/,"\n")
                            success = got == to_verify
                            puts "Failed to upload #{file} to #{pagename}" unless success
                        }
              if to_push.size > 0 # then upload also all *.png files
                images_to_push = Dir.glob("#{plugin.jar_or_src}/doc/*.png")
                images_to_push.each{
                                 |image|
                                git_mod =  get_git_modification(image)
                                wiki_mod = get_image_modification_name(image)
                                no_upload = git_mod and wiki_mod and (git_mod > wiki_mod)
                                puts "upload #{File.basename(image)} as last_git_modification is #{git_mod} last_wiki_modification was #{wiki_mod} no_upload #{no_upload.inspect}" if $VERBOSE
                                next if no_upload
                                res = @mw.upload(image, {
                                :text => 'ein Text',
                                        :ignorewarnings => 'true',
                                        :filename => File.basename(image),
                                        :comment => "Uploaded by #{File.basename(__FILE__)}",
                                        } )
                                 puts "res für #{image}  exists? #{File.exists?(image)} ist #{res.inspect} answer is #{res[0].root.elements.first}" # if $VERBOSE
                }
            end
          }
        end

        def get_git_modification(file)
          return nil unless File.exists?(file)
          git_time = `git log -1 --pretty=format:%ai #{file}`
          return nil  unless git_time.length > 8
          Time.parse(git_time.chomp).utc
        end

        def get_page_modification_time(pagename)
          json_url = "#{@wiki}?action=query&format=json&prop=revisions&titles=#{pagename}&rvprop=timestamp"
          json = RestClient.get(json_url)
          wiki_json_timestamp_to_time(json, pagename)
        end

        def pull
          @doc_projects.each{
            |prj|
            dir = File.dirname(prj)
            get_content_from_wiki(dir, File.basename(dir))
          }
          @info.plugins.each{
            |id, info|
              puts "Pulling for plugin #{id}" if $VERBOSE
              pull_docs_views(info)
              pull_docs_plugins(info)
              pull_docs_perspectives(info)
          }
          @info.features.each{
            |id, info|
              puts "Pulling for feature #{id}" if $VERBOSE
              pull_docs_features(info)
          }
          saved = Dir.pwd
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

        private
        def wiki_json_timestamp_to_time(json, page_or_img)
          return nil unless json
          begin
            m = json.match(/timestamp['"]:['"]([^'"]+)/)
            return Time.parse(m[1]) if m
          end
          nil
        end

        def check_config_file
          possibleCfgs = ['/etc/elexis-wiki-interface/config.yml', File.join(Dir.pwd, 'config.yml'), ]
          possibleCfgs.each{ |cfg| @config_yml = cfg; break if File.exists?(cfg) }
          raise "need a config file #{possibleCfgs.join(' or ')} for wiki with user/password" unless File.exists?(@config_yml)
          yaml = YAML.load_file(@config_yml)
          @user = yaml['user']
          @password = yaml['password']
          @wiki = yaml['wiki']
          puts "MediWiki #{@wiki} user #{@user} with password #{@password}" if $VERBOSE
        end

        def shorten_wiki_image(image)
          return File.basename(image) unless File.basename(image).index(':')
          File.basename(image).split(':')[1..-1].join(':')
        end

        # http://wiki.elexis.info/api.php?action=query&format=json&list=allimages&ailimit=5&aiprop=timestamp&aiprefix=Ch.elexis.notes:config.png&*
        def get_image_modification_name(image)
          json_url = "#{@wiki}?action=query&format=json&list=allimages&ailimit=5&aiprop=timestamp&aiprefix=#{shorten_wiki_image(image)}"
          json = RestClient.get(json_url)
          wiki_json_timestamp_to_time(json, image)
        end

        # helper function, as mediawiki-gateway does not handle this situation correctly
        def download_image_file(image, downloaded_image)
          short_image = shorten_wiki_image(image)
          unless File.exist? downloaded_image
            json_url = "#{@wiki}?action=query&format=json&list=allimages&ailimit=5&aiprop=url&aiprefix=#{short_image}"
            json = RestClient.get(json_url)
            unless json
              puts "JSON: Could not fetch for image #{image} using #{json_url}"
              return
            end
            begin
              answer = JSON.parse(json)
              image_url = nil
              image_url = answer['query'].first[1].first['url'] if answer['query'] and answer['query'].size >= 1 and answer['query'].first[1].size > 0
              if image_url
                      File.open(downloaded_image, 'w') do |file|
                        file.write(open(image_url).read)
                      end
              else
                puts "skipping image #{image}"
              end
              rescue => e
                puts "JSON: Could not fetch for image #{image} using #{json_url}"
                puts "      was '#{json}'"
                puts "      error was #{e.inspect}"
            end
          end
          puts "Downloaded image #{downloaded_image} #{File.size(downloaded_image)} bytes" if $VERBOSE
        end

        def get_content_from_wiki(out_dir, pageName)
          puts "get_content_from_wiki page #{pageName} -> #{out_dir}" if $VERBOSE
          out_name = File.join(out_dir, pageName + '.mediawiki')
          FileUtils.makedirs(out_dir) unless File.directory?(out_dir)
          content = @mw.get(pageName)
          if content
            ausgabe = File.open(out_name, 'w+') { |f| f.write content }
            @mw.images(pageName).each{
              |image|
                image = image.gsub(/[^\w\.:]/, '_')
                downloaded_image = File.join(out_dir, shorten_wiki_image(image))
                download_image_file(image, downloaded_image)
                break if defined?(RSpec) # speed up rspec
            }
          else
            puts "Could not fetch #{pageName} from #{@mw}" if $VERBOSE
          end
          content
        end
        def pull_docs_views(plugin)
          id = plugin.symbolicName
          plugin.views.each{
            |id, view|
            pageName = viewToPageName(plugin.symbolicName, view)
            content = get_content_from_wiki(File.join(@info.workspace_dir, File.basename(plugin.jar_or_src), 'doc'), pageName)
            @views_missing_documentation << pageName unless content
          }
        end
       def pull_docs_perspectives(plugin)
          id = plugin.symbolicName
          plugin.perspectives.each{
            |id, perspective|
            pageName = perspectiveToPageName(perspective)
            content = get_content_from_wiki(File.join(@info.workspace_dir, File.basename(plugin.jar_or_src), 'doc'), pageName)
            @perspectives_missing_documentation << pageName unless content
          }
        end
        def pull_docs_plugins(plugin)
          id = plugin.symbolicName
          pageName = id.capitalize
          content = get_content_from_wiki(File.join(@info.workspace_dir, File.basename(plugin.jar_or_src), 'doc'), pageName)
          @perspectives_missing_documentation << pageName unless content
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
end
