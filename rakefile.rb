require_relative "build/robocopy"

ADDON_NAME = "ReputationBars"
BASE_PATH = "#{File.dirname(__FILE__)}"

WOW_PATH = ENV['WOW_PATH'].nil? ? "C:\Program Files\World of Warcraft" : ENV['WOW_PATH']
if not Dir.exists?(WOW_PATH) then
	raise "You need to set environment variable 'WOW_PATH' to point to your World of Warcraft installation."
end

ADDON_PATH = File.join(WOW_PATH, "Interface", "Addons")
if not Dir.exists?(ADDON_PATH) then
	raise "Could not find addon directory #{ADDON_PATH}"
end

task :default => :deploy

desc "Update files and deploy addon to the WoW folder"
task :deploy => [:updatelocale, :maketoc, :copyaddon, :cleanup]

desc "Perform a deploy and package a release version"
task :release => [:newversion, :deploy, :package]

desc "Update Babelfish locale files"
task :updatelocale do
	Dir.chdir(File.join(BASE_PATH, "Source/Locales")) do
		sh "lua Babelfish.lua" do |ok, res|
			raise "Failed to update locale files. Error #{res.exitstatus}" unless ok
		end
	end
end

desc "Generate the TOC file stamped with the current version"
task :maketoc do
	# Generate TOC file with version and revision info
	version = File.read("version.txt").chomp
	begin
		commit = `git log -1 --pretty=format:%H`
	rescue
		commit = "unknown"
	end
	tocfile = getTocFileName()
	toc = File.read("#{tocfile}.tmpl").gsub(/%VERSION%/, version).gsub(/%REV%/, commit)
	File.open(tocfile, 'w') do |outfile|
		outfile.puts toc
	end
end

task :newversion do
	sh "lua version.lua" do |ok, res|
		raise "Failed to update version. Error #{res.exitstatus}" unless ok
	end
end

robocopy :copyaddon do |rc|
	rc.source = File.join(BASE_PATH, "Source")
	rc.target = File.join(ADDON_PATH, ADDON_NAME)
	rc.excludeFiles = "*.tmpl *.png"
end

desc "Clean up temporary files"
task :cleanup do
	tocfile = getTocFileName()
	File.delete(tocfile) if File.exists?(tocfile)
end

task :package do
	version = File.read("version.txt").chomp
	releasepath = File.join(BASE_PATH, "Releases")
	archivefile = File.join(releasepath, "#{ADDON_NAME}-#{version}.zip")
	Dir.mkdir(releasepath) unless Dir.exists?(releasepath)
	File.delete(archivefile) if File.exists?(archivefile)
	Dir.chdir(ADDON_PATH) do
		sh '"C:\Program Files\7-Zip\7z.exe"' + " a -tzip #{archivefile} #{ADDON_NAME}"
	end
end

def getTocFileName()
	return File.join(BASE_PATH, "Source/#{ADDON_NAME}.toc")
end
