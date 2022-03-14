# lua-resty-inspect
Human-readable representation of Lua tables.
This is a fork of [http://github.com/kikito/inspect.lua](http://github.com/kikito/inspect.lua).
Add features:
- when passing `json = true` to options, output will be formatted json
- skip metatable rendering by default
# Synopsis
```
local inspect = require("resty.inspect")
local t = setmetatable({a=1,b={c=2}}, {"will be skipped"})
assert(inspect(t, {json=true})==[[{
  "a" : 1,
  "b" : {
    "c" : 2
  }
}]])
```

