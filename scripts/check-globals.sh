#!/usr/bin/env bash
# Lists globals each Lua file reads or writes that are neither Lua standard nor
# declared in .luacheckrc: a stand-in for luacheck's undefined-global check when
# luacheck is not installed. Needs lua and luac (5.1 or newer) on the PATH.
#   scripts/check-globals.sh
cd "$(dirname "$0")/.."
allowed=$(lua -e '
  local env = {}
  local src = assert(io.open(".luacheckrc")):read("*a")
  local chunk = assert(load(src, "cfg", "t", env))
  chunk()
  local std = { "_G","_VERSION","assert","collectgarbage","dofile","error","getfenv","getmetatable","ipairs","load","loadfile","loadstring","module","next","pairs","pcall","print","rawequal","rawget","rawset","require","select","setfenv","setmetatable","tonumber","tostring","type","unpack","xpcall","coroutine","debug","io","math","os","package","string","table","bit" }
  for _, n in ipairs(std) do print(n) end
  for _, n in ipairs(env.globals or {}) do print(n) end
  for _, n in ipairs(env.read_globals or {}) do print(n) end' | sort -u)
status=0
for f in *.lua; do
  listing=$(luac -l -p "$f")
  used=$( { echo "$listing" | grep -oE '(GET|SET)GLOBAL[^;]*; [A-Za-z_][A-Za-z0-9_]*' | sed 's/.*; //'; echo "$listing" | grep -oE '_ENV "[A-Za-z_][A-Za-z0-9_]*"' | sed 's/_ENV "//; s/"$//'; } | sort -u)
  [ -z "$used" ] && { echo "$f: could not read any globals from the bytecode listing"; status=1; continue; }
  bad=$(comm -23 <(echo "$used") <(echo "$allowed"))
  if [ -n "$bad" ]; then echo "$f: undefined globals: $(echo $bad)"; status=1; fi
done
[ $status -eq 0 ] && echo "no undefined globals in any file ($(ls *.lua | wc -l | tr -d ' ') files checked)"
exit $status
