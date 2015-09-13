#!/usr/bin/env ruby
# TODO:
# * get list of all wiki-files and (at the end) mark all files which have to been deleted, as they are duplicates
# * Iterate of all files and with the help of helper class determine
# * best_name (short without _ if no conflict, else eg. sysmex_picture, else ch.elexis.system_picture
# * show uses to be correct (and how), show files where used (via grep in doc directory)
# TODO: FixmedikationAufruf.png
# TODO: 9ec22d37e0a1a0eb897094fec1a800481d2a28c7fc36a5a1662adcf6a271cb6d
#  :name: customedconfsmall.png
# TODO: kabel.png
require 'pp'
require 'digest'
require 'csv'
require 'yaml'
begin
  require 'pry';
rescue LoadError
end
root = File.expand_path(File.dirname(__FILE__))
@user = 'ngiger'

@case_sensitives={}
@multiple_names={}
@to_short_names={}
@nr_single_sha=[]
@short_and_sha_okay=[]
@wrong_best_name = []
@new_best_name = {}
# docs =Dir.glob('**/doc_de') + Dir.glob('**/doc') # doc_fr is mostly a duplicate of doc_de
docs = Dir.glob('**/doc') # doc_fr is mostly a duplicate of doc_de
puts "Loocking for picture files in #{docs.size} doc directories"

false_positive = %(
-rw-r--r-- 1 niklaus niklaus 42923 Sep 12 13:22 medelexis-3/at.medevit.elexis.gdt.customed/doc/customedconfsmall.png
-rw-r--r-- 1 niklaus niklaus 42923 Sep 12 13:22 medelexis-3/at.medevit.elexis.gdt.customed/doc/customedconfsmall.png
-rw-r--r-- 1 niklaus niklaus 42923 Sep 12 13:22 medelexis-3/at.medevit.elexis.gdt.customed/doc/images/elexisConfig.png
)
def get_small_name(path)
  File.basename(path).downcase.split('_')[-1]
end

def get_name_with_project(path)
  # File.dirname(path).sub(/(\.feature|\.v\d_|)\/doc/i, '').split('.')[-1] + '_' + File.basename(path)
  dir = File.dirname(path)
  found = dir.sub(/(\.feature|)\/doc/i, '').sub(/\.v\d$/, '')
  found.split('.')[-1] + '_' + File.basename(path)
end

def verify_best_name(picture)
  if picture[:bestname]
    wrong_best_name = @pictures.find_all{|x| x[:best_name] == picture[:best_name] and x[:sha256] != picture[:sha256]}
  else
    wrong_best_name = {}
  end
  if wrong_best_name.size > 0
    puts "wrong_best_name #{wrong_best_name.size} entries #{wrong_best_name}" if $VERBOSE
    # binding.pry if picture[:best_name] == 'elexis_logo.png'
    @wrong_best_name << [picture[:path], wrong_best_name.collect{|x| x[:path]} ]
    if File.basename(picture[:path]) != picture[:best_name]
      picture[:best_name] = File.basename(picture[:path])
    else
      new_name = get_name_with_project(picture[:path])
      puts "new_best_name is #{new_name} for #{picture[:path]}"
      binding.pry if new_name.eql?('customed_customedconfsmall.png')
      @new_best_name[picture[:path]] = new_name
      picture[:best_name] = new_name
    end
  else
    puts "wrong_best_name is #{wrong_best_name} for #{picture[:best_name]}" if $VERBOSE
  end
end

def set_best_name(picture)
  path = picture[:path]
  sha256 = Digest::SHA256.hexdigest(IO.read(path))
  same_sha256 = @pictures.find_all{|x| x[:sha256] == sha256}
  same_name   = @pictures.find_all{|x| x[:name] == picture[:name]}
  if same_sha256.size == 1
    puts "only 1 sha256 #{sha256} for #{path}" if $VERBOSE
    @nr_single_sha << same_sha256
    picture[:best_name] = get_small_name(path)
    return
  else
    nrSha256 = same_name.collect{|c| get_small_name(c[:sha256])}.uniq
    msg = " nrSha #{sha256.size} #{sha256}"
    if same_sha256.collect{|c| c[:name]}.uniq.size == 1 and nrSha256.size == 1
      puts "@short_and_sha_okay #{path} sha256 #{sha256} for #{same_sha256.size} files"
      binding.pry if picture[:name] == 'prefs2.png'
      @short_and_sha_okay << path
      picture[:best_name] = get_small_name(path)
      return
    end
    found = same_sha256.collect{|c| c[:name].downcase}.uniq
    if found.size == 1  and nrSha256.size == 1
      puts "case_sensitives #{found}"
      @case_sensitives[path] = same_sha256
      picture[:best_name] = get_small_name(path)
      return
    end
    multiple = same_sha256.collect{|c| c[:name]}.uniq
    to_reduce = same_sha256.collect{|c| get_small_name(c[:name])}.uniq
    if to_reduce.size == 1   and nrSha256.size == 1
      @to_short_names[path] = to_reduce
      puts "to_short_names #{multiple} =>  #{to_reduce} nrSha #{sha256.size} #{sha256}"
      picture[:best_name] = get_small_name(path)
      return
    end
    puts "multiple #{multiple} to_reduce #{to_reduce}"
    @multiple_names[path] = same_sha256
    picture[:best_name] =  get_name_with_project(picture[:path])
    # binding.pry if /prefs2.png/i.match(found.to_s)
    return
    # binding.pry
    # binding.pry if to_reduce.size == 1
  end
end

@pictures =[]
docs.each{
  |doc_dir|
  pngs = Dir.glob("#{doc_dir}/**/*.{png,jpg}")
  puts "#{doc_dir} has #{pngs.size} png" if $VERBOSE
  next if pngs.size == 0
  pngs.each {
             |png|
            sha256 = Digest::SHA256.hexdigest(IO.read(png))
            pict = { :sha256 => sha256, :name => File.basename(png), :project => File.basename(File.dirname(File.dirname(png))), :path => png}
            @pictures << pict
            }
  # break if pngs.size > 1
}

@sha_2_png = {}
@pictures.each {
  |picture|
  if @sha_2_png[picture[:sha256]]
    @sha_2_png[picture[:sha256]] << picture
  else
    @sha_2_png[picture[:sha256]] = [picture]
  end
}

@duplicates = @sha_2_png.find_all{|sha, list| list.size > 1}
@dup_non_identical = []
@duplicates.each{
                  |sha, entry|
                found = entry.collect{|x| x[:name]}.uniq
                next if found.size == 1
                projects = entry.collect{|x| x[:project]}.uniq.join(' ').to_s
                smaller = entry.collect{|x| get_small_name(x[:name])}.uniq
                next if smaller.size == 1
                puts smaller
                puts "found #{found.size} #{found}" if $VERBOSE
#                @dup_non_identical << [sha, entry.size, projects]+ found
                @dup_non_identical << [sha, entry.size]+ found
                }
msg = "Found #{@pictures.size} pictures with  #{@sha_2_png.keys.size} different hash values and #{@duplicates.size} duplicates #{@dup_non_identical.size} with different names"
msg2 = "# #{@dup_non_identical.size} with non identical names"
CSV.open('duplicates.csv', 'w+') do |csv|
  csv << ["# Generated by: #{File.basename(__FILE__)} at #{Date.today}"]
  csv << ["# #{msg}"]
  csv << ['SH256', 'Nr files', 'filename']
  @duplicates.each{
                   |sha, entry|
                  puts "#{sha} #{entry.collect{|x| x.path}}" if $VERBOSE
                  csv << [sha, entry.size] + entry.collect{|x| x[:path]}
                  }
  csv << []
  csv << [msg2]; puts msg2
  csv << []
  @dup_non_identical.each{|entry|
                  csv << entry
                  }
end

File.open('duplicates.yml', 'w+') {|f| f.puts @duplicates.to_yaml}
File.open('pictures.yml', 'w+') {|f| f.puts @pictures.to_yaml}
puts msg

@small_names = {}
@errors = []
@pictures.each{
  |x|
    small_name = get_small_name(x[:path])
    if @small_names[small_name]
      soll = @small_names[small_name][:sha256]
      ist = x[:sha256]
      if soll.eql?(ist)
        puts "small_name #{small_name} with no conflict via #{x[:sha256]}" if $VERBOSE
        next
      else
        msg ="small_name #{small_name} sha256 #{soll} conflicts via #{ist}"
        @errors << msg
        puts msg
        pp x
      # require 'pry'; binding.pry
      end
    else
      @small_names[small_name] = x
    end
}
@to_correct = []
@pictures.each{
  |x|
    small_name = get_small_name(x[:path])
    next if small_name == x[:name]
    @to_correct  << x
}
puts @to_correct.collect{|x| x[:path] }
puts "Found #{@to_correct.size} names to be corrected"
@pictures.each{
  |picture|
     res = set_best_name(picture)
}
@pictures.each{
  |picture|
     res = verify_best_name(picture)
}
@wrong_best_name = []
@pictures.each{
  |picture|
     res = verify_best_name(picture)
}
@wrong_best_name = []
@pictures.each{
  |picture|
     res = verify_best_name(picture)
}
File.open('new_best_name.yml', 'w+') {|f| f.puts @new_best_name.to_yaml}
puts "\n\nWrong_best"
pp @wrong_best_name
puts "\n\nnew_best"
pp @new_best_name
puts "\n\n@errors"
pp @errors
nrs = 0
@pictures.each{
  |x|
    next if x[:name] == x[:best_name]
  puts "Correct #{x[:name]} => #{x[:best_name]} for #{x[:sha256]} #{x[:path]}"
  nrs += 1
}
puts "prefs2"
puts @pictures.find_all{|x| x[:name] == 'prefs2.png'}
puts "Found #{@errors.size} errors using small names. Must corret #{nrs} entries"
puts "@nr_single_sha #{@nr_single_sha.size} entries"
puts "@case_sensitives #{@case_sensitives.size} entries"
puts "@multiple_names #{@multiple_names.size} entries"
puts "@to_short_names #{@to_short_names.size} entries"
puts "@short_and_sha_okay #{@short_and_sha_okay.size} entries"
total = @short_and_sha_okay.size + @to_short_names.size + @multiple_names.size + @case_sensitives.size + @nr_single_sha.size
puts "total #{total} @pictures #{@pictures.size}"
puts "@wrong_best_name #{@wrong_best_name.size} size"
puts "@new_best_name #{@new_best_name.size} size"
