--[[ Version stamp util ]]--

local tocfile = "Source/ReputationBars.toc"

local updateVersion = (arg[1] ~= "noupdate")

local fname = "version.txt"
local version = "1.0.0"			-- Default version
local file = io.open(fname, "r")
if file then
	version = file:read()
	file:close()

	if updateVersion then
		-- Increment version
		local major, minor, build = version:match("(%d+)\.(%d+)\.(%d+)")
		version = string.format("%d.%d.%d", major, minor, build + 1)
	end
end

if updateVersion then
	print("Enter new version ["..version.."] (or 'q' to quit)")
	local newversion = io.stdin:read()
	if newversion == "q" then os.exit(1) end
	if #newversion > 0 then
		version = newversion
	end

	-- Write version file
	file = io.open(fname, "w")
	assert(file, "Could not open file "..fname)
	file:write(version)
	file:close()
end

-- Read TOC template file
local toctemplatefile = tocfile..".tmpl"
print("Reading '"..toctemplatefile.."'")
file = io.open(toctemplatefile, "r")
assert(file, "Could not open file "..toctemplatefile)
local toctext = file:read("*all")
file:close()

local newtext, subs = toctext:gsub("%%VERSION%%", version)
assert(subs == 1, "Version number not found")

print("Writing '"..tocfile.."'")
print("Stamping version: "..version)

-- Write new TOC file
file = io.open(tocfile, "w")
assert(file, "Could not write file "..tocfile)
file:write(newtext)
file:close()
