#-- -*- ruby -*-
#++
# A set of Rake tasks for building the Alexandria project, organized as
# as TaskLib which is called from the project Rakefile.
#
# This TaskLib is heavily based upon 'hoe' by Ryan Davis.
# http://rubyforge.org/projects/seattlerb/
#
# Copyright (c) 2006,2007 Ryan Davis, Zen Spider Software
# Copyright (c) 2007 Cathal Mc Ginley, Gnostai
#
# This file is free software, under the terms of the MIT License.
#--
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
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# these requirements are part of core ruby
require 'pathname'
require 'rbconfig'
require 'yaml'

# these may be distributed as ordinary libraries,
# or as gems. Try the library versions first.
retrying_with_rubygems = false
begin
    require 'rake'
    require 'rake/tasklib'
    require 'rake/rdoctask'
    require 'rake/packagetask'
rescue LoadError => err
    unless retrying_with_rubygems
        require 'rubygems'
        retrying_with_rubygems = true
        retry
    else
        raise err
    end
end

#require 'rake/contrib/sshpublisher'
#require 'rake/gempackagetask'
#require 'rake/testtask'
#require 'rubyforge'



# AlexandriaBuild is a Rake TaskLib which creates a set of Rake tasks
# based on a small set of properties and the expectation of a generic
# project layout and structure.
class AlexandriaBuild < Rake::TaskLib

  attr_accessor :name, :version, :rubyforge_name
  attr_accessor :author, :email, :summary, :description

  # config objects
  attr_accessor :files
  attr_accessor :rdoc
  attr_accessor :install
  attr_accessor :debinstall
  attr_accessor :omf
  attr_accessor :gettext
  attr_accessor :doc


  def initialize(name, version)
    @name = name
    @version = version
    @rubyforge_name = name.downcase

    @files = FileConfig.new(self)
    @rdoc = RDocConfig.new(self)
    @install = InstallConfig.new(self)
    @debinstall = DebianInstallConfig.new(self)
    @omf = OMFConfig.new(self)
    @gettext = GettextConfig.new(self)
    @doc = DocConfig.new(self)

    yield self if block_given?
    define_tasks
  end

  def autogen_comment
    autogenerated_warning = "This file is automatically generated by the AlexandriaBuild installer.\nDo not edit it directly."
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


  class BuildConfig
    def initialize(build)
      @build = build
    end
    protected
    def build
      @build
    end
  end

  class FileConfig < BuildConfig
    attr_accessor :source, :rdoc, :data, :icons
    def initialize(build)
      super(build)
    end
    def libs
      source.grep(/^lib/)
    end
    def programs
      source.grep(/^bin/)
    end
    def specs
      source.grep(/^spec\/.*_spec.rb/)
    end
    def desktop
      "#{build.name}.desktop"
    end
  end


  def define_tasks
    define_clean_tasks
    define_rdoc_tasks
    define_package_tasks
    define_install_tasks
    define_debinstall_tasks
    define_omf_tasks
    define_gettext_tasks
    define_rspec_tasks
  end

  # Defines :clean and :clobber tasks from Rake's built-in definitions.
  def define_clean_tasks
    require 'rake/clean'
  end


  ## # # # rdoc tasks # # # ##

  # Defines :docs, :redocs and :clobber_docs tasks from Rake's RDocTask.
  # Many parameters can be changed from the rdoc object.
  def define_rdoc_tasks
    ## rdoc
    doc_task_name = :docs
    Rake::RDocTask.new(doc_task_name) do |rd|
      rd.main = @rdoc.main
      # no graphviz dot generation (for the moment)
      rd.rdoc_dir = @rdoc.dir
      rd.rdoc_files.push(*files.source.grep(@rdoc.pattern))
      rd.rdoc_files.push(*files.rdoc)
      title = "#{name}-#{version} Documentation"
      title = "#{rubyforge_name}'s " + title if rubyforge_name != name
      rd.title = title
    end
    task :clobber => [ paste("clobber_", doc_task_name) ]
  end

  class RDocConfig < BuildConfig
    attr_accessor :dir, :pattern, :main
    def initialize(build)
      super(build)
      @dir = 'doc/html'
      @pattern = /^(lib|bin|ext)|rdoc$/
      @main = 'README'
    end
  end


  ## # # # rspec tasks # # # ##

  def define_rspec_tasks
    begin
      require 'rubygems'
      require 'spec/rake/spectask'
      desc "Run RSpec specifications"
      Spec::Rake::SpecTask.new("spec") do |t|
        t.spec_files = @files.specs
        t.spec_opts = ["--format", "specdoc"]
      end
      namespace :spec do
        Spec::Rake::SpecTask.new("rcov") do |t|
          t.spec_files = FileList['spec/**/*_spec.rb']
          t.spec_opts = ["--format", "specdoc"]
          t.rcov_opts = ["--exclude", "spec"]
          t.rcov = true
        end
        Spec::Rake::SpecTask.new("html") do |t|
          t.spec_files = FileList['spec/**/*_spec.rb']
          t.spec_opts = ["--format", "html"]
          t.rcov_opts = ["--exclude", "spec"]
        end
      end

    rescue LoadError => err
      # @@log.warn('rspec not found') # FIX add logging
      task :spec do
        raise LoadError, "Cannot run specifications, RSpec was not found."
      end
    end
  end


  ## # # # package tasks # # # ##

  def define_package_tasks
      namespace 'pkg' do
      Rake::PackageTask.new(@name, @version) do |p|
          p.need_tar_gz = true
          p.package_files.include("README*", "COPYING", "ChangeLog", "INSTALL",
                                  "Rakefile", "TODO", "alexandria.desktop",
                                  "alexandria.desktop.in", "tasks.rb",
                                  "bin/**/*", "data/**/*", "debian/**/*",
                                  "doc/**/*", "lib/**/*", "po/**/*",
                                  "schemas/**/*", "spec/**/*", "tests/**/*")
      end
      end
      task :clobber => ['pkg:clobber_package']
  end

  ## # # # install tasks # # # ##

  def install_file(src_dir, file, dest_dir, mode)
    source_basedir = Pathname.new(src_dir)
    source_file = Pathname.new(file)
    dest_basedir = Pathname.new(dest_dir)
    if source_file.file?
      source_path = source_file.dirname.relative_path_from(source_basedir)
    end
    dest = source_path ? dest_basedir + source_path : dest_basedir
    FileUtils.mkdir_p dest unless test ?d, dest
    puts "Installing #{file} to #{dest}"
    File.install(file.to_s, dest.to_s, mode)
  end

  def define_install_tasks
    task :pre_install # just an empty hook

    task :install_files do
      @install.groups.each do |src, files, dest, mode|
        files.each do |file|
          install_file(src, file, dest, mode)
        end
      end
    end

    task :post_install # another empty hook

    desc "Install the package. Override destination with $PREFIX"
    task :install => [:pre_install, :install_files, :post_install]

  end


  class InstallConfig < BuildConfig

    attr_accessor :prefix, :rubylib

    def initialize(build)
      super(build)
      ruby_prefix = Config::CONFIG['prefix']
      sitelibdir = Config::CONFIG['sitelibdir']
      @prefix = ENV['PREFIX'] || ruby_prefix
      if @prefix == ruby_prefix
        @rubylib = sitelibdir
      else
        libpart = sitelibdir[ruby_prefix.size .. -1]
        @rubylib = File.join(@prefix, libpart)
      end
      @groups = []
    end

    def groups
      if @groups.empty?
        @groups.push(*default_installation)
      end
      @groups
    end

    def default_installation
      default_groups = base_installation
      default_groups.push(*icon_installation)
      default_groups.push(*desktop_installation)
      default_groups.push(*locale_installation)
      default_groups.push(*manpage_installation)
      default_groups.push(*documentation_installation)
      default_groups
    end

    def base_installation
      [
       ['lib',  build.files.libs,     rubylib,  0644],
       ['data', build.files.data,     sharedir, 0644],
       ['bin',  build.files.programs, bindir,   0755]
      ]
    end

    def icon_installation
      icon_dir = File.join(sharedir, 'icons', 'hicolor')
      icon_group = []
      build.files.icons.each do |filename|
        filename =~ /.*\/(.+)\/.+/
        size = $1
        dest = File.join(icon_dir, size, 'apps')
        icon_group << [File.dirname(filename), filename, dest, 0644]
      end
      icon_group
    end

    def desktop_installation
      desktop_dir = File.join(sharedir, 'applications')
      [['.', build.files.desktop, desktop_dir, 0644]]
    end

    def locale_installation
        [['data', build.gettext.mo_files, sharedir, 0644]]
    end

    def documentation_installation
        doc_dir = File.join(File.join(sharedir, 'doc'), build.name)
        curdir_files = []
        docdir_files = []
        build.doc.doc_files.each do |f|
            if f =~ /^doc\//
                docdir_files << f
            else
                curdir_files << f
            end
        end
        [
         ['doc', docdir_files, doc_dir, 0644],
         ['.', curdir_files, doc_dir, 0644]
        ]
    end

    def manpage_installation
        man_dir = File.join(File.join(sharedir, 'man'), 'man1')
        [['doc', build.doc.man_files, man_dir, 0644]]
    end

    def bindir
      File.join(@prefix, 'bin')
    end
    def sharedir
      File.join(@prefix, 'share')
    end
    def appsharedir
      File.join(sharedir, build.name)
    end
  end

  ## # # # debian # # # ##

  def stage_install_file(src_dir, file, dest_dir, mode)
    stage_dest = File.join(@debinstall.staging_dir, dest_dir)
    install_file(src_dir, file, stage_dest, mode)
  end

  def template_copy(src, dest, data)
    src_text = File.open(src).read()
    dest_text = src_text.gsub(/#(\w+)#/) { |match| data[$1.intern] }
    FileUtils.mkdir_p(File.dirname(dest))
    File.open(dest, 'w') { |f| f.write(dest_text) }
  end

  def define_debinstall_tasks
    namespace "debian" do

      task :stage_pre_install => [:pre_install]

      task :stage_post_install
      # just an empty hook, note we do NOT invoke post_install here

      task :stage_install_files do # HACK cut-n-paste blues!
        @debinstall.groups.each do |src, files, dest, mode|
          files.each do |file|
            stage_install_file(src, file, dest, mode)
          end
        end
      end

      task :stage_install_files_workaround do
        # some files are not copied over straight away, because
        # of how FileList globs work (they are generated after the
        # globs are evaluated)

        # HACK gconf
        gconf_dir = File.join(@debinstall.staging_dir, "/usr/share/gconf/schemas")
        FileUtils.mkdir_p(gconf_dir)
        File.install("schemas/alexandria.schemas", gconf_dir, 0644)

        # HACK copyright
        doc_dir = File.join(@debinstall.staging_dir, "/usr/share/doc/#{@name}")
        FileUtils.mkdir_p(doc_dir)
        File.install("debian/copyright", doc_dir, 0644)
        FileUtils.rm_f(File.join(doc_dir, 'COPYING'))
        File.install("debian/changelog", doc_dir, 0644)

        autogen_files = ["lib/alexandria/config.rb",
                         "lib/alexandria/version.rb",
                         "lib/alexandria/default_preferences.rb"]
        autogen_files.each do |file|
          stage_install_file('lib', file, @debinstall.rubylib, 0644)
          puts "HACK:: installing -> 'lib', #{file}, #{@debinstall.rubylib}"
        end
      end

      task :stage_install => [:stage_pre_install, :stage_install_files, :stage_install_files_workaround, :stage_post_install] do
        # HACK change /usr/bin/env line in alexandria script
        script = File.join(@debinstall.staging_dir, '/usr/bin/alexandria')
        script_contents = File.open(script).read()
        script_contents.sub!(/\/usr\/bin\/env\ ruby/, '/usr/bin/env ruby1.8')
        File.open(script, 'w') do |f|
            f.write(script_contents)
        end
      end

      task :deb_files => [:stage_install] do
        # create dir
        debian_dir = File.join(@debinstall.staging_dir, "DEBIAN")
        FileUtils.mkdir_p(debian_dir)

        # copy files from debian/*
        files = %w{postinst postrm prerm}
        files.each do |file|
          FileUtils.cp("debian/#{file}", File.join(debian_dir, file))
        end

        # create DEBIAN/control and debian/files
        `dpkg-gencontrol -isp`
      end

      ## obviously this task needs 'fakeroot' and 'dpkg' to be installed
      task :build_deb => [:deb_files] do

        puts "Creating deb file #{@debinstall.deb}"
        debfile = File.join(File.dirname(@debinstall.staging_dir), @debinstall.deb)
        msg = `fakeroot dpkg-deb --build #{@debinstall.staging_dir} #{debfile}`
        puts msg
      end

      task :deb_clean do |t|
        FileUtils.rm_rf(@debinstall.staging_dir)
        FileUtils.rm_rf("debian/files")
        FileUtils.rm_rf("build-stamp")
      end

      task :deb_clobber do |t|
        debfile = File.join(File.dirname(@debinstall.staging_dir), @debinstall.deb)
        FileUtils.rm_f(debfile)
      end

      desc "Create a deb file"
      task :deb => [:build_deb, :deb_clean]

    end
    task :clean => ["debian:deb_clean"]
    task :clobber => ["debian:deb_clobber"]

  end

  class DebianInstallConfig < InstallConfig

    attr_accessor :staging_dir, :deb

    # Debian is peculiar about where it installs ruby libraries.
    # Its 'sitelibdir' (for ruby 1.8) is /usr/local/lib/site_ruby/1.8
    # According to the Linux Standards Base (LSB) a package manager
    # should not install anything to /usr/local
    # So, to install to /usr/lib/ruby, deb files will install to
    # 'rubylibdir' instead (this is /usr/lib/ruby/1.8)
    def initialize(build)
      super(build)
      ruby_prefix = Config::CONFIG['prefix']
      sitelibdir = Config::CONFIG['rubylibdir']
      @prefix = ENV['PREFIX'] || ruby_prefix
      if @prefix == ruby_prefix
        @rubylib = sitelibdir
      else
        libpart = sitelibdir[ruby_prefix.size .. -1]
        @rubylib = File.join(@prefix, libpart)
      end
      @groups = []
      @staging_dir = nil
      @deb = "#{build.name}_#{build.version}_all.deb"
    end

  end


  ## # # # omf tasks # # # ##

  def define_omf_tasks
    desc "Generate Open Metadata Framework files"
    task :omf => @omf.omf_files

    rule '.omf' => ['.omf.in'] do |t|
      path = File.join(@install.sharedir, 'gnome', 'help',
                       @name, @omf.locale_for(t.name), "#{name}.xml")
      data = IO.read(t.source)
      data.sub!(/PATH_TO_DOC_FILE/, path)
      File.open(t.name, 'w') { |io| io.puts data }
    end

    task :omf_clobber do |t|
      @omf.omf_files.each do |f|
        FileUtils.rm_f(f)
      end
    end
    task :clobber => [:omf_clobber]
  end

  class OMFConfig < BuildConfig
    attr_accessor :omf_dir
    def initialize(build)
      super(build)
      @omf_dir = "data/omf/#{build.name}"
    end
    def locale_for(omf_file)
      omf_file =~ /.*-(.+)\.omf/
      $1
    end
    def in_files
      FileList["#{@omf_dir}/*.omf.in"]
      #Dir.glob("#{@omf_dir}/**")
    end
    def omf_files
      in_files.map { |f| f.sub(/.omf.in/, '.omf')}
    end
  end


  ## # # # gettext tasks # # # ##

  def define_gettext_tasks
    # extract translations from PO files into other files
    file files.desktop => ["#{files.desktop}.in",
                                  *@gettext.po_files] do |f|
      system("intltool-merge -d #{@gettext.po_dir} #{f.name}.in #{f.name}")
    end

    # create MO files
    rule( /\.mo$/ => [ lambda { |dest| @gettext.source_file(dest) }]) do |t|
      dest_dir = File.dirname(t.name)
      FileUtils.makedirs(dest_dir) unless FileTest.exists?(dest_dir)
      puts "Generating #{t.name}"
      system("msgfmt #{t.source} -o #{t.name}")
      raise "msgfmt failed for #{t.source}" if $? != 0
    end

    desc "Generate gettext localization files"
    task :gettext => [files.desktop, *@gettext.mo_files]

    task :clobber_gettext do
      FileUtils.rm_f(files.desktop)
      FileUtils.rm_rf(@gettext.mo_dir)
    end
    task :clobber => [:clobber_gettext]
  end

  class DocConfig < BuildConfig
      attr_accessor :man_files
      attr_accessor :doc_files
      def initialize(build)
          super(build)
      end
  end

  class GettextConfig < BuildConfig
    attr_accessor :po_dir, :po_files_glob
    attr_accessor :mo_dir, :mo_files_regex
    def initialize(build)
      super(build)
      @po_dir = 'po'
      @po_files_glob = "#{@po_dir}/*.po"
      @mo_dir = 'data/locale'
      @mo_files_regex = /.*\/(.+)\/LC_MESSAGES\/.+\.mo/
    end
    def po_files
      FileList[po_files_glob]
    end
    def po_file_for(locale)
      "#{po_dir}/#{locale}.po"
    end
    def locales
      po_files.map { |po| File.basename(po).split('.')[0] }
    end
    def mo_files
      locales.map { |loc| mo_file_for(loc) }
    end
    def mo_file_for(locale)
      "#{mo_dir}/#{locale}/LC_MESSAGES/#{build.name}.mo"
    end
    def source_file(dest_file)
      dest_file =~ mo_files_regex
      po_file_for($1)
    end
  end


end
