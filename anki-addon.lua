-- This is a sample custom writer for pandoc.  It produces output
-- that is very similar to that of pandoc's HTML writer.
-- There is one new feature: code blocks marked with class 'dot'
-- are piped through graphviz and images are included in the HTML
-- output using 'data:' URLs. The image format can be controlled
-- via the `image_format` metadata field.
--
-- Invoke with: pandoc -t sample.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua sample.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

local pipe = pandoc.pipe
local stringify = (require 'pandoc.utils').stringify

-- The global variable PANDOC_DOCUMENT contains the full AST of
-- the document which is going to be written. It can be used to
-- configure the writer.
local meta = PANDOC_DOCUMENT.meta

-- Choose the image format based on the value of the
-- `image_format` meta value.
local image_format = meta.image_format
  and stringify(meta.image_format)
  or 'png'
local image_mime_type = ({
    jpeg = 'image/jpeg',
    jpg = 'image/jpeg',
    gif = 'image/gif',
    png = 'image/png',
    svg = 'image/svg+xml',
  })[image_format]
  or error('unsupported image format `' .. image_format .. '`')

-- Character escaping
local function escape(s, in_attribute)
  return s:gsub('[<>&"\']',
    function(x)
      if x == '<' then
        return '&lt;'
      elseif x == '>' then
        return '&gt;'
      elseif x == '&' then
        return '&amp;'
      elseif in_attribute and x == '"' then
        return '&quot;'
      elseif in_attribute and x == "'" then
        return '&#39;'
      else
        return x
      end
    end)
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= '' then
      table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
  return '\n\n'
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will do the template processing as usual.
function Doc(body, metadata, variables)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add(body)
  if #notes > 0 then
    add('<ol class="footnotes">')
    for _,note in pairs(notes) do
      add(note)
    end
    add('</ol>')
  end
  return table.concat(buffer,'') .. ''
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
  return escape(s)
end

function Space()
  return ' '
end

function SoftBreak()
  return ' '
end

function LineBreak()
  return '\n'
end

function Emph(s)
  return '<i>' .. s .. '</i>'
end

function Strong(s)
  return '<b>' .. s .. '</b>'
end

function Subscript(s)
  return s
end

function Superscript(s)
  return s
end

function SmallCaps(s)
  return s
end

function Strikeout(s)
  return s
end

function Link(s, tgt, tit, attr)
  return '<a href="' .. escape(tgt,true) .. '" title="' ..
         escape(tit,true) .. '"' .. attributes(attr) .. '>' .. s .. '</a>'
end

function Image(s, src, tit, attr)
  return '<img src="' .. escape(src,true) .. '" title="' ..
         escape(tit,true) .. '" ' .. attributes(attr) ..'/>'
end

function Code(s, attr)
  return '<code>' .. escape(s) .. '</code>'
end

function InlineMath(s)
  return s
end

function DisplayMath(s)
  return s
end

function SingleQuoted(s)
  return '&lsquo;' .. s .. '&rsquo;'
end

function DoubleQuoted(s)
  return '&ldquo;' .. s .. '&rdquo;'
end

function Note(s)
  local num = #notes + 1
  -- insert the back reference right before the final closing tag.
  s = string.gsub(s,
          '(.*)</', '%1 <a href="#fnref' .. num ..  '">&#8617;</a></')
  -- add a list item with the note to the note table.
  table.insert(notes, '<li id="fn' .. num .. '">' .. s .. '</li>')
  -- return the footnote reference, linked to the note.
  return '<a id="fnref' .. num .. '" href="#fn' .. num ..
            '"><sup>' .. num .. '</sup></a>'
end

function Span(s, attr)
  return s
end

function RawInline(format, str)
  return '<code>' .. str .. '</code>'
end

function Cite(s, cs)
  return '<i>' .. s .. '</i>'
end

function Plain(s)
  return s
end

function Para(s)
  return s
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
  if lev == 1 then
    return '<b>' .. string.upper(s) .. '</b>'
  elseif lev == 2 then
    return '<b>' .. s .. '</b>'
  elseif lev == 3 then
    return '<i>' .. s .. '</i>'
  else 
    return s
  end
end

function BlockQuote(s)
  return '<code>\n' .. s .. '\n</code>'
end

function HorizontalRule()
  return "<br><br>"
end

function LineBlock(ls)
  return '<code>' .. table.concat(ls, '\n') .. '</code>'
end

function CodeBlock(s, attr)
  -- If code block has class 'dot', pipe the contents through dot
  -- and base64, and include the base64-encoded png as a data: URL.
  if attr.class and string.match(' ' .. attr.class .. ' ',' dot ') then
    local img = pipe('base64', {}, pipe('dot', {'-T' .. image_format}, s))
    return '<img src="data:' .. image_mime_type .. ';base64,' .. img .. '"/>'
  -- otherwise treat as code (one could pipe through a highlighter)
  else
    return '<code>\n' .. escape(s) .. '</code>'
  end
end

function BulletList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, '<li>' .. item .. '</li>')
  end
  return '<ul>' .. table.concat(buffer, '') .. '</ul>'
end

function OrderedList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, '<li>' .. item .. '</li>')
  end
  return '<ol>' .. table.concat(buffer, '') .. '</ol>'
end

function DefinitionList(items)
  local buffer = {}
  for _,item in pairs(items) do
    local k, v = next(item)
    table.insert(buffer, '<dt>' .. k .. '</dt><dd>' ..
                   table.concat(v, '</dd><dd>') .. '</dd>')
  end
  return '<dl>' .. table.concat(buffer, '') .. '</dl>'
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
local function html_align(align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

function CaptionedImage(src, tit, caption, attr)
  if #caption == 0 then
    return '<img src="' .. escape(src,true) .. '" ' .. attributes(attr) .. '"/><br><br>'
  else
    local ecaption = escape(caption)
    return '<img src="' .. escape(src,true) .. '" alt="' .. ecaption  .. '" ' .. attributes(attr) .. '/>'
  end
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add('<table>')
  if caption ~= '' then
    add('<caption>' .. escape(caption) .. '</caption>')
  end
  if widths and widths[1] ~= 0 then
    for _, w in pairs(widths) do
      add('<col width="' .. string.format('%.0f%%', w * 100) .. '" />')
    end
  end
  local header_row = {}
  local empty_header = true
  for i, h in pairs(headers) do
    local align = html_align(aligns[i])
    table.insert(header_row,'<th align="' .. align .. '">' .. h .. '</th>')
    empty_header = empty_header and h == ''
  end
  if not empty_header then
    add('<tr class="header">')
    for _,h in pairs(header_row) do
      add(h)
    end
    add('</tr>')
  end
  local class = 'even'
  for _, row in pairs(rows) do
    class = (class == 'even' and 'odd') or 'even'
    add('<tr class="' .. class .. '">')
    for i,c in pairs(row) do
      add('<td align="' .. html_align(aligns[i]) .. '">' .. c .. '</td>')
    end
    add('</tr>')
  end
  add('</table>')
  return table.concat(buffer,'')
end

function RawBlock(format, str)
  if format == 'html' then
    return str
  else
    return ''
  end
end

function Div(s, attr)
  return s
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return '' end
  end
setmetatable(_G, meta)
