
--print("[Pre-commit] Starting reference replacement")

local lfs = require("lfs")

do -- XML
	function parseargs(s)
	  local arg = {}
	  string.gsub(s, "([%-%w:]+)=([\"'])(.-)%2", function (w, _, a)
		arg[w] = a
	  end)
	  return arg
	end
		
	function collect(s)
	  local stack = {}
	  local top = {}
	  table.insert(stack, top)
	  local ni,c,label,xarg, empty
	  local i, j = 1, 1
	  while true do
		ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
		if not ni then break end
		local text = string.sub(s, i, ni-1)
		if not string.find(text, "^%s*$") then
		  table.insert(top, text)
		end
		if empty == "/" then  -- empty element tag
		  table.insert(top, {label=label, xarg=parseargs(xarg), empty=1, parent=top})
		elseif c == "" then   -- start tag
		  top = {label=label, xarg=parseargs(xarg), parent=top}
		  table.insert(stack, top)   -- new level
		else  -- end tag
		  local toclose = table.remove(stack)  -- remove top
		  top = stack[#stack]
		  if #stack < 1 then
			error("nothing to close with "..label)
		  end
		  if toclose.label ~= label then
			error("trying to close "..toclose.label.." with "..label)
		  end
		  table.insert(top, toclose)
		end
		i = j+1
	  end
	  local text = string.sub(s, i)
	  if not string.find(text, "^%s*$") then
		table.insert(stack[#stack], text)
	  end
	  if #stack > 1 then
		error("unclosed "..stack[#stack].label)
	  end
	  return stack[1]
	end
end

local function iterate(path,func)
	for file in lfs.dir(path) do
		if file:sub(1,1) ~= "." then
			file = path.."\\"..file
			local attr = lfs.attributes(file)
			if attr.mode == "directory" then
				iterate(file,func)
			else
				func(file)
			end
		end
	end
end

local function needsNewlines(node)
	if type(node) ~= "table" then return false end
	return node.label ~= "null"
end

local function tostringXML(node,tabs,out)
	local nl = needsNewlines(node)
	out:write((nl and tabs or "").."<"..node.label)
	local xargs = {}
	for k in pairs(node.xarg) do
		xargs[#xargs+1] = k
	end table.sort(xargs)
	for i=1,#xargs do
		out:write((" %s=%q"):format(xargs[i],node.xarg[xargs[i]]))
	end out:write(">")
	local nled = false
	for i=1,#node do
		local child = node[i]
		local nl = needsNewlines(child)
		if type(child) == "table" then
			if i == 1 and nl then out:write("\n") end
			tostringXML(child,tabs.."\t",out)
		else
			out:write(child)
		end nled = nled or nl
	end 
	tabs = nled and nl and tabs or ""
	nled = nl and "\n" or ""
	out:write(tabs.."</"..node.label..">"..nled)
end

local function scanNode(node,refs,reffed,reffing)
	for i=1,#node do
		local child = node[i]
		if type(child) == "table" then
			if child.xarg.referent then
				refs[child.xarg.referent] = child
			end
			if child.label == "Ref" and child[1] then
				reffed[child[1]] = true
				reffing[child] = child[1]
			elseif child.xarg.name == "ScriptGuid" then
				child[1] = "null"
			end scanNode(child,refs,reffed,reffing)
		end
	end
end

local function getKey(tab,val)
	for i=1,#tab do
		if tab[i] == val then
			return i
		end
	end return 0
end

local function generateRef(node,map)
	local res = {}
	while node and node.xarg.class do
		res[#res+1] = node.xarg.class:gsub("%U","")
		res[#res+1] = getKey(node.parent,node)
		node = node.parent
	end
	res = table.concat(res)
	if not map[res] then return res end
	for i=0,math.huge do
		if not map[res..i] then
			return res..i
		end
	end
end

local function clense(path)
	print("[Pre-Commit] Clensing "..path)
	local xml = io.open(path,"r")
	xml = xml:read("*a"),xml:close()
	xml = collect(xml)[1]
	local refs,reffed = {},{}
	local reffing,map = {},{}
	scanNode(xml,refs,reffed,reffing,hist)
	for k,v in pairs(refs) do
		if reffed[v.xarg.referent] then
			local old = v.xarg.referent
			local ref = generateRef(v,map)
			v.xarg.referent,map[ref] = ref,true
			for a,b in pairs(reffing) do
				if b == old then
					a[1] = ref
				end
			end
		else
			v.xarg.referent = nil
		end
	end
	local buffer = {}
	local out = io.open(path,"w")
	tostringXML(xml,"",out) out:close()
end

local failed = false
--[[
iterate(lfs.currentdir(),function(p)
	if p:sub(-6) == ".rbxlx" or p:sub(-6) == ".rbxmx" then
		local s,e = pcall(clense,p)
		if not s then
			e = e:gsub("\n","\n\t") failed = true
			io.stdout:write("[Pre-Commit] Clensing failed:\n\t"..e.."\n")
			io.stdout:write("\tDoes the file not contain proper ROBLOX XML format?")
		end
	end
end)]]

for p in io.stdin:lines() do
	if p:sub(-6) == ".rbxlx" or p:sub(-6) == ".rbxmx" then
		local s,e = pcall(clense,p)
		if not s then
			e = e:gsub("\n","\n\t") failed = true
			io.stderr:write("[Pre-Commit] Clensing failed:\n\t"..e.."\n")
			io.stderr:write("\tDoes the file not contain proper ROBLOX XML format?\n")
		end
	end
end

os.exit(failed and 1 or 0)