# -*- ruby -*-
#--
# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2011, 2014 Matijs van Zuijlen
#
# This file is part of the Alexandria build system.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

load 'tasks/setup.rb'

require 'rake/packagetask'

$:.unshift(File.join(File.dirname(__FILE__), 'util/rake'))
require 'fileinstall'
require 'gettextgenerate'
require 'omfgenerate'


stage_dir = ENV['DESTDIR'] || 'tmp'
prefix_dir = ENV['PREFIX'] || '/usr'

PROJECT='alexandria'
PREFIX = prefix_dir
share_dir = ENV['SHARE'] || "#{PREFIX}/share"
SHARE = share_dir

DATA_VERSION = '0.6.3'
PROJECT_VERSION = '0.6.8'
DISPLAY_VERSION = '0.6.8'

gettext = GettextGenerateTask.new(PROJECT) do |g|
  g.generate_po_files('po', 'po/*.po', 'share/locale')
  g.generate_desktop('alexandria.desktop.in', 'alexandria.desktop')
end

omf = OmfGenerateTask.new(PROJECT) do |o|
  o.gnome_helpfiles_dir = "#{SHARE}/gnome/help"
  o.generate_omf('data/omf/alexandria', 'share/omf/alexandria/*.in')
end

def install_common(install_task)
  install_task.install_exe('bin', 'bin/*', "#{PREFIX}/bin")
  install_task.install('lib', 'lib/**/*.rb', install_task.rubylib)

  share_files = ['data/alexandria/**/*', 'data/gnome/**/*.*',
                 'data/locale/**/*.mo', 'data/omf/**/*.omf', 
                 'data/sounds/**/*.ogg'] #, 'data/menu/*']
  install_task.install('data', share_files, SHARE)

  icon_files = ['data/app-icon/**/*.png', 'data/app-icon/scalable/*.svg']
  install_task.install_icons(icon_files, "#{SHARE}/icons")
  install_task.install('data/app-icon/32x32', 'data/app-icon/32x32/*.xpm', "#{SHARE}/pixmaps")

  install_task.install('','schemas/alexandria.schemas', "#{SHARE}/gconf")
  install_task.install('', 'alexandria.desktop', "#{SHARE}/applications")
  install_task.install('doc','doc/alexandria.1', "#{SHARE}/man/man1")

end

debinstall = FileInstallTask.new(:package_staging, stage_dir, true) do |i|
  install_common(i)

end

task :debian_install => :install_package_staging

packageinstall = FileInstallTask.new(:package) do |j|
  install_common(j)

  docs = ['README', 'NEWS', 'INSTALL', 'COPYING', 'TODO']
  devel_docs = ['doc/AUTHORS', 'doc/BUGS', 'doc/FAQ', 
                'doc/cuecat_support.rdoc']
  j.install('', docs, "#{SHARE}/doc/#{PROJECT}") 
  j.install('doc', devel_docs, "#{SHARE}/doc/#{PROJECT}")

  j.uninstall_empty_dirs(["#{SHARE}/**/#{PROJECT}/",
                          "#{j.rubylib}/#{PROJECT}/"
                         ])
end


task :clobberp do
  puts CLOBBER
end

## autogenerated files

def autogen_comment
  autogenerated_warning = "This file is automatically generated by the #{PROJECT} installer.\nDo not edit it directly."
  lines = autogenerated_warning.split("\n")
  result = lines.map { |line| "# #{line}"}
  result.join("\n") + "\n\n"
end

def generate(filename)
  File.open(filename, 'w') do |file|
    puts "Generating #{filename}"
    file.print autogen_comment
    file_contents = yield
    file.print file_contents.to_s
  end
end

# generate lib/alexandria/version.rb
file 'lib/alexandria/version.rb' => ['Rakefile'] do |f|
  generate(f.name) do
    <<EOS
module Alexandria
  VERSION = "#{PROJECT_VERSION}"
  DATA_VERSION = "#{DATA_VERSION}"
  DISPLAY_VERSION = "#{DISPLAY_VERSION}"
end
EOS
  end
end

# generate default_preferences.rb
def convert_with_type(value, type)
  case type
  when 'int'
    value.to_i
  when 'float'
    value.to_f
  when 'bool'
    value == 'true'
  else
    value.strip
  end
end

SCHEMA_PATH = 'schemas/alexandria.schemas'
  
# This generates default_preferences.rb by copying over values from 
# providers_priority key in alexandria.schemas (necessary?)

file 'lib/alexandria/default_preferences.rb' => [SCHEMA_PATH] do |f|
  require 'rexml/document'
  generated_lines = []

  doc = REXML::Document.new(IO.read(SCHEMA_PATH))
  doc.elements.each('gconfschemafile/schemalist/schema') do |element|
    default = element.elements['default'].text
    next unless default
    varname = File.basename(element.elements['key'].text)
    type = element.elements['type'].text

    if type == 'list' or type == 'pair'
      ary = default[1..-2].split(',')
      next if ary.empty?
      if type == 'list'
        list_type = element.elements['list_type'].text
        ary.map! { |x| convert_with_type(x, list_type) }
      elsif type == 'pair'
        next if ary.length != 2
        ary[0] = convert_with_type(ary[0],
                                   element.elements['car_type'].text)
        ary[1] = convert_with_type(ary[1],
                                   element.elements['cdr_type'].text)
      end
      default = ary.inspect
    else
      default = convert_with_type(default, type).inspect.to_s
    end

    generated_lines << varname.inspect + ' => ' + default
  end

  generate(f.name) do
    <<EOS
module Alexandria
  class Preferences
    DEFAULT_VALUES = {#{generated_lines.join(",\n      ")}}
  end
end
EOS
  end
end


autogenerated_files = ['lib/alexandria/config.rb',
                       'lib/alexandria/version.rb',
                       'lib/alexandria/default_preferences.rb']

desc "Generate ruby files needed for the installation"
task :autogen => autogenerated_files

task :autogen_clobber do |t|
  autogenerated_files.each do |file|
    FileUtils.rm_f(file)
  end
end
task :clobber => [:autogen_clobber]


## # # # default task # # # ##

task :build => [:autogen, :gettext, :omf]

task :default => [:build]

# pre-release tasks

ULTRA_CLOBBER = []
task :ultra_clobber => :clobber do
  ULTRA_CLOBBER.each do |file|
    FileUtils::Verbose.rm_f(file)
  end
end

file 'ChangeLog' do
  unless `svn2cl --version`
    raise Exception, "Unable to generate ChangeLog; install svn2cl"
  end
  sh "svn2cl -r HEAD:700 -o ChangeLog.tmp"
  # Revision r703 is on the date of the last ChangeLog.0 entry
  if File.exist?('ChangeLog.tmp')
    # fix up file (remove blank lines beginning with tabs)
    File.open('ChangeLog', 'wb') do |change_log|
      File.open('ChangeLog.tmp').each_line do |line|
        if line.chomp =~ /(^[\t][\s]+$)/
          change_log.write("\n")
        else
          change_log.write(line)
        end
      end
    end
    File.delete('ChangeLog.tmp')
  end
end
ULTRA_CLOBBER << "ChangeLog"



## # # # package task # # # ##

Rake::PackageTask.new(PROJECT, DISPLAY_VERSION) do |p|
  p.need_tar_gz = true
  p.package_files.include("README*", "COPYING", "ChangeLog", "INSTALL",
                          "NEWS", "Rakefile", "util/**/*",
                          "TODO", "alexandria.desktop",
                          "alexandria.desktop.in",
                          "bin/**/*", "data/**/*", "misc/**/*",
                          "doc/**/*", "lib/**/*", "po/**/*",
                          "schemas/**/*", "spec/**/*", "tests/**/*")
end

task :tgz => [:build] do 
  `rake package`
end

## # # # system installation # # # ##

task :pre_install => [:build]
task :scrollkeeper do
  unless system("which scrollkeeper-update")
    raise "scrollkeeper-update cannot be found, is Scrollkeeper correctly installed?"
  end
  system('scrollkeeper-update -q') or raise 'Scrollkeeper update failed'
end

task :gconf do
  return if ENV['GCONF_DISABLE_MAKEFILE_SCHEMA_INSTALL']

  unless system("which gconftool-2")
    raise "gconftool-2 cannot be found, is GConf2 correctly installed?"
  end

  ENV['GCONF_CONFIG_SOURCE'] = `gconftool-2 --get-default-source`.chomp
  Dir["schemas/*.schemas"].each do |schema|
    system("gconftool-2 --makefile-install-rule '#{schema}'")
  end
  #system("killall -HUP gconfd-2")
end

task :update_icon_cache do
  system("gtk-update-icon-cache -f -t /usr/share/icons/hicolor") # HACK
end

task :post_install => [:scrollkeeper, :gconf, :update_icon_cache]

desc "Install Alexandria"
task :install => [:pre_install, :install_package, :post_install]

desc "Uninstall Alexandria"
task :uninstall => [:uninstall_package] # TODO gconf etc...
