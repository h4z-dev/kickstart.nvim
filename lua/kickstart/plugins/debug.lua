-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'codelldb',
        'delve',
      },
    }
    local function get_python_executable()
      -- Check if venv-selector has an active venv
      local venv_path = vim.fn.getenv 'VIRTUAL_ENV' or vim.fn.getenv 'CONDA_PREFIX'
      if venv_path and vim.fn.executable(venv_path .. '/bin/python') == 1 then
        return venv_path .. '/bin/python'
      end

      -- Check if 'uv' has detected an active venv (common for `uv shell`)
      -- This is more implicit and relies on environment variables or current directory structure
      if vim.fn.executable 'uv' == 1 then
        -- Try to find a .venv or similar uv-managed environment in current or parent dirs
        local current_dir = vim.fn.getcwd()
        local path_sep = package.config:sub(1, 1) -- Get system path separator
        local parts = vim.split(current_dir, path_sep)
        for i = #parts, 1, -1 do
          local check_path = table.concat(vim.list_slice(parts, 1, i), path_sep) .. path_sep .. '.venv'
          if vim.fn.isdirectory(check_path) == 1 then
            local uv_venv_python = check_path .. '/bin/python' -- Standard uv venv layout
            if vim.fn.executable(uv_venv_python) == 1 then
              return uv_venv_python
            end
          end
        end
      end

      -- Fallback to system Python if no venv detected
      return 'python' -- Rely on PATH
    end

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close
    -- cpp lldb dap
    dap.adapters.codelldb = {
      type = 'server',
      port = '${port}',
      executable = {
        command = vim.fn.stdpath 'data' .. '/mason/packages/codelldb/codelldb',
        args = { '--port', '${port}' },
      },
    }
    -- debugpy adapter configuration
    dap.adapters.python = {
      type = 'executable',
      -- This path is where Mason installs debugpy. Verify this.
      command = vim.fn.stdpath 'data' .. '/mason/bin/debugpy',
      args = { '-m', 'debugpy.adapter' },
    }

    -- Python DAP configurations (equivalent to launch.json)
    dap.configurations.python = {
      {
        type = 'python',
        request = 'launch',
        name = 'Launch file',
        -- Use the dynamically determined python executable
        python = get_python_executable(),
        program = '${file}', -- Debug the current file
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal', -- Or 'externalTerminal' for a new window
        stopOnEntry = true,
      },
      {
        type = 'python',
        request = 'launch',
        name = 'Launch module',
        python = get_python_executable(),
        module = function()
          return vim.fn.input('Module name: ', '', 'file')
        end,
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal',
        stopOnEntry = true,
      },
      {
        type = 'python',
        request = 'attach',
        name = 'Attach to process',
        python = get_python_executable(),
        host = '127.0.0.1',
        port = 5678, -- Default debugpy port
        cwd = '${workspaceFolder}',
      },
    }

    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
