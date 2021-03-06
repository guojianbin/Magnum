COPYRIGHT = "Copyright 2007-2012 Chris Patterson, Dru Sellers, et al. All rights reserved."

require File.dirname(__FILE__) + "/build_support/BuildUtils.rb"

include FileTest
require 'albacore'
require File.dirname(__FILE__) + "/build_support/ilmergeconfig.rb"
require File.dirname(__FILE__) + "/build_support/ilmerge.rb"

BUILD_NUMBER_BASE = '2.1.3'
PRODUCT = 'Magnum'
CLR_TOOLS_VERSION = 'v4.0.30319'

BUILD_CONFIG = ENV['BUILD_CONFIG'] || "Release"
BUILD_CONFIG_KEY = ENV['BUILD_CONFIG_KEY'] || 'NET40'
BUILD_PLATFORM = ''
TARGET_FRAMEWORK_VERSION = (BUILD_CONFIG_KEY == "NET40" ? "v4.0" : "v3.5")
MSB_USE = (BUILD_CONFIG_KEY == "NET40" ? :net4 : :net35)
OUTPUT_PATH = (BUILD_CONFIG_KEY == "NET40" ? 'net-4.0' : 'net-3.5')

props = {
  :src => File.expand_path("src"),
  :build_support => File.expand_path("build_support"),
  :stage => File.expand_path("build_output"),
  :output => File.join( File.expand_path("build_output"), OUTPUT_PATH ),
  :artifacts => File.expand_path("build_artifacts"),
  :keyfile => File.expand_path("Magnum.snk"),
  :nuspecfile => File.expand_path("Magnum.nuspec"),
  :nuspecfileTF => File.expand_path("Magnum.TestFramework.nuspec"),
  :zipfile => "Magnum-#{BUILD_NUMBER_BASE}.zip"
}

puts "Building for .NET Framework #{TARGET_FRAMEWORK_VERSION} in #{BUILD_CONFIG}-mode."

desc "Cleans, compiles, il-merges, unit tests, prepares examples, packages zip and runs MoMA"
task :all => [:default, :package, :moma]

desc "**Default**, compiles and runs tests"
task :default => [:clean, :compile, :ilmerge, :tests]

desc "**DOOES NOT CLEAR OUTPUT FOLDER**, compiles and runs tests"
task :unclean => [:compile, :ilmerge, :tests]

desc "Update the common version information for the build. You can call this task without building."
assemblyinfo :global_version do |asm|
  asm_version = BUILD_NUMBER_BASE + ".0"
  commit_data = get_commit_hash_and_date
  commit = commit_data[0]
  commit_date = commit_data[1]
  build_number = "#{BUILD_NUMBER_BASE}.1"
  tc_build_number = ENV["BUILD_NUMBER"]
  build_number = "#{BUILD_NUMBER_BASE}.#{tc_build_number}" unless tc_build_number.nil?

  puts "Setting assembly file version to #{build_number}"

  # Assembly file config
  asm.product_name = PRODUCT
  asm.description = "Magnum - A library for the larger than average developer. http://github.com/phatboyg/Magnum. magnum-project.net."
  asm.version = asm_version
  asm.file_version = build_number
  asm.custom_attributes :AssemblyInformationalVersion => "#{asm_version}",
	:ComVisibleAttribute => false,
	:CLSCompliantAttribute => false
  asm.copyright = COPYRIGHT
  asm.output_file = 'src/SolutionVersion.cs'
  asm.namespaces "System", "System.Reflection", "System.Runtime.InteropServices", "System.Security"
end

desc "Prepares the working directory for a new build"
task :clean do
	FileUtils.rm_rf props[:artifacts]
	FileUtils.rm_rf props[:stage]
	# work around latency issue where folder still exists for a short while after it is removed
	waitfor { !exists?(props[:stage]) }
	waitfor { !exists?(props[:artifacts]) }

	Dir.mkdir props[:stage]
	Dir.mkdir props[:artifacts]
end

desc "Cleans, versions, compiles the application and generates build_output/."
task :compile => [:global_version, :build] do
	puts 'Copying unmerged dependencies to output folder'
#	copyOutputFiles File.join(props[:src], "Magnum.Routing/bin/#{BUILD_CONFIG}"), "Magnum.Routing.{dll,pdb,xml}", props[:output]

#	targ = File.join(props[:output], "NHibernate")
#	copyOutputFiles File.join(props[:src], "Magnum.ForNHibernate/bin/#{BUILD_CONFIG}"), "Magnum.ForNHibernate.{dll,pdb,xml}", targ

	targ = File.join(props[:output], "TestFramework")
	copyOutputFiles File.join(props[:src], "Magnum.TestFramework/bin/#{BUILD_CONFIG}"), "Magnum.TestFramework.{dll,pdb,xml}", targ

#	targ = File.join(props[:output], "DebugVisualizer")
#	copyOutputFiles File.join(props[:src], "Magnum.Visualizers/bin/#{BUILD_CONFIG}"), "Magnum.Visualizers.dll", targ
#	copyOutputFiles File.join(props[:src], "Magnum.Visualizers/bin/#{BUILD_CONFIG}"), "Microsoft*dll", targ
#	copyOutputFiles File.join(props[:src], "Magnum.Visualizers/bin/#{BUILD_CONFIG}"), "QuickGraph*dll", targ
end

ilmerge :ilmerge do |ilm|
	out = File.join(props[:output], 'Magnum.dll')
	ilm.output = out
	ilm.internalize = File.join(props[:build_support], 'internalize.txt')
	ilm.working_directory = File.join(props[:src], "Magnum.FileSystem/bin/#{BUILD_CONFIG}")
	ilm.target = :library
        ilm.use MSB_USE
	ilm.log = File.join( props[:src], "Magnum.FileSystem","bin","#{BUILD_CONFIG}", 'ilmerge.log' )
	ilm.allow_dupes = true
	ilm.references = [ 'Magnum.dll', 'Magnum.FileSystem.dll', 'Ionic.Zip.dll' ]
	ilm.references.push 'System.Threading.dll' unless BUILD_CONFIG_KEY == 'NET40'
	ilm.keyfile = props[:keyfile]
end

desc "Only compiles the application."
msbuild :build do |msb|
	msb.properties :Configuration => BUILD_CONFIG,
	    :BuildConfigKey => BUILD_CONFIG_KEY,
	    :TargetFrameworkVersion => TARGET_FRAMEWORK_VERSION,
	    :Platform => 'Any CPU'
	msb.properties[:TargetFrameworkVersion] = TARGET_FRAMEWORK_VERSION unless BUILD_CONFIG_KEY == 'NET35'
	msb.properties[:SignAssembly] = 'true'
	msb.properties[:AssemblyOriginatorKeyFile] = props[:keyfile]
	#msb.verbosity = 'diag'
	msb.use :net4 #MSB_USE
	msb.targets :Rebuild
	msb.solution = 'src/Magnum.sln'
end

def copyOutputFiles(fromDir, filePattern, outDir)
	FileUtils.mkdir_p outDir unless exists?(outDir)
	Dir.glob(File.join(fromDir, filePattern)){|file|
		copy(file, outDir) if File.file?(file)
	}
end


desc "Runs unit tests"
nunit :tests => [:compile] do |nunit|

          nunit.command = File.join('src', 'packages','NUnit.Runners.2.6.3', 'tools', 'nunit-console.exe')
          nunit.parameters = "/framework=#{CLR_TOOLS_VERSION}", '/nothread', '/nologo', '/labels', "\"/xml=#{File.join(props[:artifacts], 'nunit-test-results.xml')}\""
          nunit.assemblies = FileList[File.join("tests", "Magnum.Specs.dll")]
end

desc "Target used for the CI server. It both builds, tests and packages."
task :ci => [:default, :package, :moma]

task :package => [:zip_output, :nuget]

desc "ZIPs up the build results and runs the MoMA analyzer."
zip :zip_output do |zip|
	zip.dirs = [props[:stage]]
	zip.output_path = File.join(props[:artifacts], props[:zipfile])
end

desc "Runs the MoMA mono analyzer on the project files. Start the executable manually without --nogui to update the profiles once in a while though, or you'll always get the same report from the analyzer."
task :moma => [:compile] do
	puts "Analyzing project fitness for mono:"
	dlls = project_outputs(props).join(' ')
	sh "lib/MoMA/MoMA.exe --nogui --out #{File.join(props[:artifacts], 'MoMA-report.html')} #{dlls}"
end

# TODO: create tasks for installing and running samples!

desc "Builds the nuget package"
task :nuget do
	sh "src/.nuget/nuget pack -Verbose -Symbols #{props[:nuspecfile]} /OutputDirectory build_artifacts"
	sh "src/.nuget/nuget pack -Symbols #{props[:nuspecfileTF]} /OutputDirectory build_artifacts"
end

def project_outputs(props)
	props[:projects].map{ |p| "src/#{p}/bin/#{BUILD_CONFIG}/#{p}.dll" }.
		concat( props[:projects].map{ |p| "src/#{p}/bin/#{BUILD_CONFIG}/#{p}.exe" } ).
		find_all{ |path| exists?(path) }
end

def get_commit_hash_and_date
	begin
		commit = `git log -1 --pretty=format:%H`
		git_date = `git log -1 --date=iso --pretty=format:%ad`
		commit_date = DateTime.parse( git_date ).strftime("%Y-%m-%d %H%M%S")
	rescue
		commit = "git unavailable"
	end

	[commit, commit_date]
end

def waitfor(&block)
	checks = 0

	until block.call || checks >10
		sleep 0.5
		checks += 1
	end

	raise 'Waitfor timeout expired. Make sure that you aren\'t running something from the build output folders, or that you have browsed to it through Explorer.' if checks > 10
end
