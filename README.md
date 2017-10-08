# Roblox-Version-Control
Git hook that transforms .rbxmx and .rbxlx files on commit to be very git-friendly

### Installation
* Install Lua and have it in the PATH variable *(both 5.1 and 5.2 are fine)* **[once]**
	* You need to be able to open a shell / commandprompt and run `lua`
	* Lua for Windows: https://code.google.com/archive/p/luaforwindows/
* Copy pre-commit and process.lua to your repository's hook repositories **[always]**
	* By default this is the .git/hooks/ folder in your repository
	* This step has to be done whenever you create (**or clone!**) a repository

### Usage
Once you've copied the files to the hooks folder, you're good to go. Just commit as usual, and the hooks will automatically take care of stuff.

### Notes
* This system breaks committing patches of .rbxlx and .rbxmx files
*(the whole file gets committed, not just the patches you indicated)*
	* Committing patches of non-.rbxlx and non-.rbxmx files still works as usual
	* Committing patches of roblox XML would lead to bugs anyway, so see this as *a feature*

### Inner workings
Whenever you commit, pre-commit will be executed. This'll start the process.lua script and give it a list of all staged files, including in subdirectories. The script will filter for .rbxlx / .rbxmx and "clense" them. Clensing does these things:
* Scan for all instances
	* Filling a dictionary of `[referent] = xmlNode` *(each non-clensed instance gets added)*
	* Create a (inverse) list `refs` of all `<string name="Ref">` nodes
		* The value also gets stored in a dictionary `reffed` as `reffed[referent] = true`
	* Set the content of all `<string name="ScriptGuid">` nodes to `null`
* Go through `refs`
	* If instance is referenced *(check whether it's in `reffed`)*
		* Generate a new reference *(sort of a (forcefully unique) hash calculated from ancestors)*
		* Set the `referent` field of the XML node to the new reference
		* Go through all Ref nodes (stored in `refs`) and replace matching referents
	* Otherwise remove the `referent` field of the XML node

The XML structure is tostringed. It alphabetically writes XML attributes, as the default behaviour (`for k,v in pairs(xarg) do`) could result in a different order every time, which could lead to unexpected line changes. The tostring method also has been finetuned in a tiny bit to have the same indentation structure as default .rbxmx / .rbxlx files.

Original file gets overwritten with the new XML, which is robbed of some of its useless data that changes between studio sessions.

Pre-commit will re-`git add` every staged .rbxmx / .rbxlx file (leading to patch commits breaking)

If after processing the .rbxmx / .rbxlx files there seems to be no changes anymore, the commit is cancelled, even if you used the `--allow-empty` option. Otherwise, if everything went well, pre-commit returns error code 0, which lets the commit process continue.

### Showcase

[![Git hook for roblox version control](https://img.youtube.com/vi/ykXK5vCz46o/0.jpg)](https://www.youtube.com/watch?v=ykXK5vCz46o "Git hook for roblox version control")
