Writer = pandoc.scaffolding.Writer

-- Anki addon respected tags: img, a, b, i, code, ul, ol, li.
Writer.Inline.Image = function (nd)
  local attr = ""
  if nd.caption ~= nil then
    attr = attr .. '" alt="' .. escape(pandoc.utils.stringify(nd.caption), true) .. '"'
  end
  if nd.attributes ~= nil then
    for k, v in pairs(nd.attributes) do
      attr = attr .. ' ' .. k .. '="' .. v .. '"'
    end
  end
  return "<img src=\"" .. escape(nd.src, true) .. attr .. "/>"
end

Writer.Inline.Link = function (nd)
  return "<a href=\"" .. escape(nd.target, true) .. "\">"
    .. Writer.Inlines(nd.content) .. "</a>"
end

Writer.Inline.Strong = function (nd)
  return "<b>" .. Writer.Inlines(nd.content) .. "</b>"
end

Writer.Inline.Emph = function (nd)
  return "<i>" .. Writer.Inlines(nd.content) .. "</i>"
end

Writer.Inline.Cite = function (nd)
  return '"' .. Writer.Inlines(nd.content) .. '"'
end

Writer.Inline.Code = function (nd)
  return "<code>" .. escape(nd.text, false) .. "</code>"
end

Writer.Block.CodeBlock = function (nd)
  -- local str = string.sub(nd.text, string.find(nd.text, "\n") + 1)
  return "\n<code>" .. escape(str, false) .. "</code>\n"
  -- return "<code>" .. escape(nd.text, false) .. "</code>"
end

Writer.Block.BulletList = function (nd)
  local str = "<ul>"
  for i, itm in pairs(nd.content) do
    str = str .. "<li>" .. Writer.Blocks(itm) .. "</li>"
  end
  return str .. "</ul>"
end

Writer.Block.OrderedList = function (nd)
  local str = "<ol>"
  for i, itm in pairs(nd.content) do
    str = str .. "<li>" .. Writer.Blocks(itm) .. "</li>"
  end
  return str .. "</ol>"
end

-- Override block spacing for HTML as input keeps `\n`
-- Block types:
--    BlockQuote: no space
--    BulletList: no space
--    CodeBlock: no space
--    OrderedList: no space
--    Plain: no space
--    Para: space
--    RawBlock: space
--    DefinitionList: space
--    Div: space
--    Figure: space
--    Header: space
--    HorizontalRule: space
--    LineBlock: space
--    Table: space

Writer.Blocks = function (nd)
  local function spacing(cur, nxt)
    local function lookup (nd_)
      local space = {
        ['CodeBlock'] = 2,
        ['BlockQuote'] = 0,
        ['BulletList'] = 0,
        ['OrderedList'] = 0,
        ['Plain'] = 0,
        ['Header'] = 1,
        ['Para'] = 2,
        ['RawBlock'] = 2,
        ['DefinitionList'] = 2,
        ['Div'] = 2,
        ['Figure'] = 2,
        ['HorizontalRule'] = 2,
        ['LineBlock'] = 2,
        ['Table'] = 2
      }
 
      if nd_ == nil then
        return 0
      end
      for key, val in pairs(space) do
       if key == nd_ then
          return val
        end
      end
      return 2
    end

    local curs = lookup(cur)
    local nxts = lookup(nxt)
    if curs == 0 or nxts == 0 then
      return ''
    elseif curs == 1 then
      return '\n'
    else
      return '\n\n'
    end
  end

  local str = ""
  local prev = nil
  for _, itm in pairs(nd) do
    str = str .. spacing(prev, itm.tag) .. Writer.Block(itm)
    prev = itm.tag
  end
  return str
end

-- Reasonable rendering of markdown input
Writer.Inline.Str = function (nd)
  return escape(nd.text, false)
end

Writer.Inline.Space = function (nd)
  return " "
end

Writer.Block.Plain = function (nd)
  return Writer.Inlines(nd.content)
end

Writer.Block.Para = function (nd)
  return Writer.Inlines(nd.content)
end

Writer.Inline.Quoted = function (nd)
  local q = '"'
  if nd.quotetype == 'SingleQuote' then
    q = "'"
  end
  return q .. Writer.Inlines(nd.content) .. q
end

Writer.Block.BlockQuote = function (nd)
  return "<code>" .. Writer.Inlines(nd.content) .. "</code>"
end

Writer.Block.Header = function (nd)
  local str = escape(pandoc.utils.stringify(nd.content), false)
  if nd.level == 1 then
    return "<b>" .. pandoc.text.upper(str) .. "</b>"
  elseif nd.level == 2 then
    return "<b>" .. pandoc.text.upper(str) .. "</b>"
  elseif nd.level == 3 then
    return "<b>" .. str .. "</b>"
  elseif nd.level == 4 then
    return "<b><i>" .. str .. "</i></b>"
  elseif nd.level == 5 then
    return "<i>" .. str .. "</i>"
  else
    return str
  end
end

Writer.Block.Figure = function (nd)
  local str = ""
  for _, itm in pairs(nd.content) do
    str = str .. Writer.Block(itm)
  end
  return str
end

Writer.Inline.SoftBreak = function (nd)
  return " "
end


-- Character escaping
function escape(s, in_attribute)
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
