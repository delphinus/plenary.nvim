local strings = require('plenary.strings')
local eq = assert.are.same

describe('strings', function()
  describe('strdisplaywidth', function()
    for _, case in ipairs{
      {str = 'abcde', expected = {single = 5, double = 5}},
      -- This space below is a tab (U+0009)
      {str = 'abc	de', expected = {single = 10, double = 10}},
      {str = 'アイウエオ', expected = {single = 10, double = 10}},
      {str = '├─┤', expected = {single = 3, double = 6}},
    } do
      for _, ambiwidth in ipairs{'single', 'double'} do
        local msg = ('ambiwidth = %s, "%s" -> %d'):format(ambiwidth, case.str, case.expected[ambiwidth])
        local original = vim.o.ambiwidth
        vim.o.ambiwidth = ambiwidth
        it('lua: '..msg, function()
          eq(case.expected[ambiwidth], strings.strdisplaywidth(case.str))
        end)
        it('vim: '..msg, function()
          eq(case.expected[ambiwidth], vim.fn.strdisplaywidth(case.str))
        end)
        vim.o.ambiwidth = original
      end
    end
  end)

  describe('strcharpart', function()
    for _, case in ipairs{
      {args = {'abcde', 2}, expected = 'cde'},
      {args = {'abcde', 2, 2}, expected = 'cd'},
      {args = {'アイウエオ', 2, 2}, expected = 'ウエ'},
      {args = {'├───┤', 2, 2}, expected = '──'},
    } do
      local msg = ('("%s", %d, %s) -> "%s"'):format(case.args[1], case.args[2], tostring(case.args[3]), case.expected)
      it('lua: '..msg, function()
        eq(case.expected, strings.strcharpart(unpack(case.args)))
      end)
      it('vim: '..msg, function()
        eq(case.expected, vim.fn.strcharpart(unpack(case.args)))
      end)
    end
  end)

  describe('truncate', function()
    for _, case in ipairs{
      {args = {'abcde', 6}, expected = {single = 'abcde', double = 'abcde'}},
      {args = {'abcde', 5}, expected = {single = 'abcde', double = 'abcde'}},
      {args = {'abcde', 4}, expected = {single = 'abc…', double = 'ab…'}},
      {args = {'アイウエオ', 11}, expected = {single = 'アイウエオ', double = 'アイウエオ'}},
      {args = {'アイウエオ', 10}, expected = {single = 'アイウエオ', double = 'アイウエオ'}},
      {args = {'アイウエオ', 9}, expected = {single = 'アイウエ…', double = 'アイウ…'}},
      {args = {'アイウエオ', 8}, expected = {single = 'アイウ…', double = 'アイウ…'}},
      {args = {'├─┤', 7}, expected = {single = '├─┤', double = '├─┤'}},
      {args = {'├─┤', 6}, expected = {single = '├─┤', double = '├─┤'}},
      {args = {'├─┤', 5}, expected = {single = '├─┤', double = '├…'}},
      {args = {'├─┤', 4}, expected = {single = '├─┤', double = '├…'}},
      {args = {'├─┤', 3}, expected = {single = '├─┤', double = '…'}},
      {args = {'├─┤', 2}, expected = {single = '├…', double = '…'}},
    } do
      for _, ambiwidth in ipairs{'single', 'double'} do
        local msg = ('ambiwidth = %s, [%s, %d] -> %s'):format(
          ambiwidth,
          case.args[1],
          case.args[2],
          case.expected[ambiwidth]
        )
        it(msg, function()
          local original = vim.o.ambiwidth
          vim.o.ambiwidth = ambiwidth
          eq(case.expected[ambiwidth], strings.truncate(unpack(case.args)))
          vim.o.ambiwidth = original
        end)
      end
    end
  end)

  describe('align_str', function()
    for _, case in ipairs{
      {args = {'abcde', 8}, expected = {single = 'abcde   ', double = 'abcde   '}},
      {args = {'アイウ', 8}, expected = {single = 'アイウ  ', double = 'アイウ  '}},
      {args = {'├─┤', 8}, expected = {single = '├─┤     ', double = '├─┤  '}},
      {args = {'abcde', 8, true}, expected = {single = '   abcde', double = '   abcde'}},
      {args = {'アイウ', 8, true}, expected = {single = '  アイウ', double = '  アイウ'}},
      {args = {'├─┤', 8, true}, expected = {single = '     ├─┤', double = '  ├─┤'}},
    } do
      for _, ambiwidth in ipairs{'single', 'double'} do
        local msg = ('ambiwidth = %s, [%s, %d, %s] -> "%s"'):format(
          ambiwidth,
          case.args[1],
          case.args[2],
          tostring(case.args[3]),
          case.expected[ambiwidth]
        )
        it(msg, function()
          local original = vim.o.ambiwidth
          vim.o.ambiwidth = ambiwidth
          eq(case.expected[ambiwidth], strings.align_str(unpack(case.args)))
          vim.o.ambiwidth = original
        end)
      end
    end
  end)

  describe('dedent', function()
    local function lines(t)
      return table.concat(t, '\n')
    end
    for _, case in ipairs{
      {
        msg = 'empty string',
        tabstop = 8,
        args = {''},
        expected = '',
      },
      {
        msg = 'in case tabs are longer than spaces',
        tabstop = 8,
        args = {
          lines{
            '		<Tab><Tab> -> 13 spaces',
            '     5 spaces -> 0 space',
          },
        },
        expected = lines{
          '           <Tab><Tab> -> 13 spaces',
          '5 spaces -> 0 space',
        },
      },
      {
        msg = 'in case tabs are shorter than spaces',
        tabstop = 2,
        args = {
          lines{
            '		<Tab><Tab> -> 0 space',
            '     5spaces -> 1 space',
          },
        },
        expected = lines{
          '<Tab><Tab> -> 0 space',
          ' 5spaces -> 1 space',
        },
      },
      {
        msg = 'ignores empty lines',
        tabstop = 2,
        args = {
          lines{
            '',
            '',
            '',
            '        8 spaces -> 3 spaces',
            '',
            '',
            '     5 spaces -> 0 space',
            '',
            '',
            '',
          },
        },
        expected = lines{
          '',
          '',
          '',
          '   8 spaces -> 3 spaces',
          '',
          '',
          '5 spaces -> 0 space',
          '',
          '',
          '',
        },
      },
      {
        msg = 'no indent',
        tabstop = 2,
        args = {
          lines{
            '	<Tab> -> 2 spaces',
            'Here is no indent.',
            '    4 spaces will remain',
          },
        },
        expected = lines{
          '  <Tab> -> 2 spaces',
          'Here is no indent.',
          '    4 spaces will remain',
        },
      },
      {
        msg = 'leave_indent = 4',
        tabstop = 2,
        args = {
          lines{
            '	<Tab> -> 6 spaces',
            '0 indent -> 4 spaces',
            '    4 spaces -> 8 spaces',
          },
          4,
        },
        expected = lines{
          '      <Tab> -> 6 spaces',
          '    0 indent -> 4 spaces',
          '        4 spaces -> 8 spaces',
        },
      },
      {
        msg = 'typical usecase: <Tab> to 5 spaces',
        tabstop = 4,
        args = {
          lines{
            '',
            '		Chapter 1',
            '',
            '	  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed',
            '	do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
            '',
            '	  Ut enim ad minim veniam, quis nostrud exercitation ullamco',
            '	laboris nisi ut aliquip ex ea commodo consequat.',
            '',
          },
          5,
        },
        expected = lines{
          '',
          '         Chapter 1',
          '',
          '       Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed',
          '     do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
          '',
          '       Ut enim ad minim veniam, quis nostrud exercitation ullamco',
          '     laboris nisi ut aliquip ex ea commodo consequat.',
          '',
        },
      },
      {
        msg = 'examples in tjdevries/tree-sitter-lua',
        tabstop = 2,
        args = {[[
          - item one with
            some
            additional
            context
            - item one.one
              with more
              context
              - item
                one.one.one
                with even
                more
                context
            - item one.two
              no context
          - item two]]},
        expected = lines{
          '- item one with',
          '  some',
          '  additional',
          '  context',
          '  - item one.one',
          '    with more',
          '    context',
          '    - item',
          '      one.one.one',
          '      with even',
          '      more',
          '      context',
          '  - item one.two',
          '    no context',
          '- item two',
        },
      },
    } do
      local msg = ('tabstop = %d, %s'):format(case.tabstop, case.msg)
      it(msg, function()
        local original = vim.bo.tabstop
        vim.bo.tabstop = case.tabstop
        eq(case.expected, strings.dedent(unpack(case.args)))
        vim.bo.tabstop = original
      end)
    end
  end)
end)
