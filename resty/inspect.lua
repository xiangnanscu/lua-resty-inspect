local _tl_compat;
if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then
  local p, m = pcall(require, 'compat53.module');
  if p then
    _tl_compat = m
  end
end
local math = _tl_compat and _tl_compat.math or math;
local string = _tl_compat and _tl_compat.string or string;
local table = _tl_compat and _tl_compat.table or table
local inspect = {Options = {}}

inspect._VERSION = 'inspect.lua 3.1.0'
inspect._URL = 'http://github.com/kikito/inspect.lua'
inspect._DESCRIPTION = 'human-readable representations of tables'
inspect._LICENSE = [[
  MIT LICENSE

  Copyright (c) 2022 Enrique García Cota

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
inspect.KEY = setmetatable({}, {
  __tostring = function()
    return 'inspect.KEY'
  end
})
inspect.METATABLE = setmetatable({}, {
  __tostring = function()
    return 'inspect.METATABLE'
  end
})

local tostring = tostring

local function rawpairs(t)
  return next, t, nil
end

local function smartQuote(str)
  if str:match('"') and not str:match("'") then
    return "'" .. str .. "'"
  end
  return '"' .. str:gsub('"', '\\"') .. '"'
end

local shortControlCharEscapes = {
  ["\a"] = "\\a",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
  ["\v"] = "\\v",
  ["\127"] = "\\127"
}
local longControlCharEscapes = {["\127"] = "\127"}
for i = 0, 31 do
  local ch = string.char(i)
  if not shortControlCharEscapes[ch] then
    shortControlCharEscapes[ch] = "\\" .. i
    longControlCharEscapes[ch] = string.format("\\%03d", i)
  end
end

local function escape(str)
  return (str:gsub("\\", "\\\\"):gsub("(%c)%f[0-9]", longControlCharEscapes):gsub("%c", shortControlCharEscapes))
end

local function isIdentifier(str)
  return type(str) == "string" and not not str:match("^[_%a][_%a%d]*$")
end

local flr = math.floor
local function isSequenceKey(k, sequenceLength)
  return type(k) == "number" and flr(k) == k and 1 <= (k) and k <= sequenceLength
end

local defaultTypeOrders = {
  ['number'] = 1,
  ['boolean'] = 2,
  ['string'] = 3,
  ['table'] = 4,
  ['function'] = 5,
  ['userdata'] = 6,
  ['thread'] = 7
}

local function sortKeys(a, b)
  local ta, tb = type(a), type(b)

  if ta == tb and (ta == 'string' or ta == 'number') then
    return (a) < (b)
  end

  local dta, dtb = defaultTypeOrders[ta], defaultTypeOrders[tb]

  if dta and dtb then
    return defaultTypeOrders[ta] < defaultTypeOrders[tb]
  elseif dta then
    return true
  elseif dtb then
    return false
  end

  return ta < tb
end

local function getSequenceLength(t)
  local len = 1
  local v = rawget(t, len)
  while v ~= nil do
    len = len + 1
    v = rawget(t, len)
  end
  return len - 1
end

local function getNonSequentialKeys(t)
  local keys, keysLength = {}, 0
  local sequenceLength = getSequenceLength(t)
  for k, _ in rawpairs(t) do
    if not isSequenceKey(k, sequenceLength) then
      keysLength = keysLength + 1
      keys[keysLength] = k
    end
  end
  table.sort(keys, sortKeys)
  return keys, keysLength, sequenceLength
end

local function countTableAppearances(t, tableAppearances)
  tableAppearances = tableAppearances or {}

  if type(t) == "table" then
    if not tableAppearances[t] then
      tableAppearances[t] = 1
      for k, v in rawpairs(t) do
        countTableAppearances(k, tableAppearances)
        countTableAppearances(v, tableAppearances)
      end
      countTableAppearances(getmetatable(t), tableAppearances)
    else
      tableAppearances[t] = tableAppearances[t] + 1
    end
  end

  return tableAppearances
end

local function makePath(path, a, b)
  local newPath = {}
  local len = #path
  for i = 1, len do
    newPath[i] = path[i]
  end

  newPath[len + 1] = a
  newPath[len + 2] = b

  return newPath
end

local function processRecursive(process, item, path, visited)
  if item == nil then
    return nil
  end
  if visited[item] then
    return visited[item]
  end

  local processed = process(item, path)
  if type(processed) == "table" then
    local processedCopy = {}
    visited[item] = processedCopy
    local processedKey

    for k, v in rawpairs(processed) do
      processedKey = processRecursive(process, k, makePath(path, k, inspect.KEY), visited)
      if processedKey ~= nil then
        processedCopy[processedKey] = processRecursive(process, v, makePath(path, processedKey), visited)
      end
    end

    local mt = processRecursive(process, getmetatable(processed), makePath(path, inspect.METATABLE), visited)
    if type(mt) ~= 'table' then
      mt = nil
    end
    setmetatable(processedCopy, mt)
    processed = processedCopy
  end
  return processed
end

local Inspector = {}

local Inspector_mt = {__index = Inspector}

function Inspector:puts(a, b, c, d, e)
  local buffer = self.buffer
  local len = #buffer
  buffer[len + 1] = a
  buffer[len + 2] = b
  buffer[len + 3] = c
  buffer[len + 4] = d
  buffer[len + 5] = e
end

function Inspector:down(f)
  self.level = self.level + 1
  f()
  self.level = self.level - 1
end

function Inspector:tabify()
  self:puts(self.newline, string.rep(self.indent, self.level))
end

function Inspector:alreadyVisited(v)
  return self.ids[v] ~= nil
end

function Inspector:getId(v)
  local id = self.ids[v]
  if not id then
    local tv = type(v)
    id = (self.maxIds[tv] or 0) + 1
    self.maxIds[tv] = id
    self.ids[v] = id
  end
  return tostring(id)
end

function Inspector:putValue(_)
end

function Inspector:putKey(k)
  if isIdentifier(k) then
    self:puts( not self.json and k or ('"'..k..'"'))
    return
  end
  self:puts("[")
  self:putValue(k)
  self:puts("]")
end

function Inspector:putTable(t)
  if t == inspect.KEY or t == inspect.METATABLE then
    self:puts(tostring(t))
  elseif self:alreadyVisited(t) then
    self:puts('<table ', self:getId(t), '>')
  elseif self.level >= self.depth then
    self:puts('{...}')
  else
    if self.tableAppearances[t] > 1 then
      self:puts('<', self:getId(t), '>')
    end

    local nonSequentialKeys, nonSequentialKeysLength, sequenceLength = getNonSequentialKeys(t)
    local mt = getmetatable(t)
    local render_mt = type(mt) == 'table' and self.metatable
    self:puts('{')
    self:down(function()
      local count = 0
      for i = 1, sequenceLength do
        if count > 0 then
          self:puts(',')
        end
        self:puts(' ')
        self:putValue(t[i])
        count = count + 1
      end

      for i = 1, nonSequentialKeysLength do
        local k = nonSequentialKeys[i]
        if count > 0 then
          self:puts(',')
        end
        self:tabify()
        self:putKey(k)
        self:puts(' '..self.sep..' ')
        self:putValue(t[k])
        count = count + 1
      end

      if render_mt then
        if count > 0 then
          self:puts(',')
        end
        self:tabify()
        self:puts('<metatable> = ')
        self:putValue(mt)
      end
    end)

    if nonSequentialKeysLength > 0 or render_mt then
      self:tabify()
    elseif sequenceLength > 0 then
      self:puts(' ')
    end

    self:puts('}')
  end
end

function Inspector:putValue(v)
  local tv = type(v)
  if tv == 'string' then
    self:puts(smartQuote(escape(v)))
  elseif tv == 'number' or tv == 'boolean' or tv == 'nil' or tv == 'cdata' or tv == 'ctype' then
    self:puts(tostring(v))
  elseif tv == 'table' then
    self:putTable(v)
  else
    self:puts('<', tv, ' ', self:getId(v), '>')
  end
end

function inspect.inspect(root, options)
  options = options or {}

  local depth = options.depth or (math.huge)
  local newline = options.newline or '\n'
  local indent = options.indent or '  '
  local process = options.process
  local json = options.json or false
  local sep, metatable
  if json then
    sep = ':'
    metatable = false
  else
    sep = options.sep or '='
    metatable = options.metatable or false
  end
  if process then
    root = processRecursive(process, root, {}, {})
  end

  local inspector = setmetatable({
    depth = depth,
    level = 0,
    buffer = {},
    ids = {},
    maxIds = {},
    newline = newline,
    indent = indent,
    tableAppearances = countTableAppearances(root),
    metatable = metatable,
    sep = sep,
    json = json,
  }, Inspector_mt)

  inspector:putValue(root)

  return table.concat(inspector.buffer)
end

setmetatable(inspect, {
  __call = function(_, root, options)
    return inspect.inspect(root, options)
  end
})

return inspect
