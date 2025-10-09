return {
    {
        -- Debug Framework
        "mfussenegger/nvim-dap",
        dependencies = {
            "nvim-neotest/neotest",
            "GustavEikaas/easy-dotnet.nvim",
        },
        config = function()
            local dap = require("dap")
            local neotest = require("neotest")

            local map = vim.keymap.set

            local opts = { noremap = true, silent = true }

-- stylua: ignore start
            map("n", "<F5>", function() dap.continue() end, opts)
            map("n", "<F6>", function() neotest.run.run({strategy = 'dap'}) end, opts)
            map("n", "<F9>", function() dap.toggle_breakpoint() end, opts)
            map("n", "<F10>", function() dap.step_over() end, opts)
            map("n", "<F11>", function() dap.step_into() end, opts)
            map("n", "<F8>", function() dap.step_out() end, opts)
            -- map("n", "<F12>", function() dap.step_out() end, opts)
            map("n", "<leader>dr", function() dap.repl.open() end, opts)
            map("n", "<leader>dl", function() dap.run_last() end, opts)
            map(
                "n",
                "<leader>dt",
                function() neotest.run.run({strategy = 'dap'}) end,
                { noremap = true, silent = true, desc = "debug nearest test" }
            )
            require("easy-dotnet.netcoredbg").register_dap_variables_viewer()
        end,
    },
    {
        -- UI for debugging
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
        },
        config = function()
            local dapui = require("dapui")
            local dap = require("dap")

            --- open ui immediately when debugging starts
            dap.listeners.after.event_initialized["dapui_config"] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
                dapui.close()
            end
            -- https://emojipedia.org/en/stickers/search?q=circle
            vim.fn.sign_define("DapBreakpoint", {
                text = "⚪",
                texthl = "DapBreakpointSymbol",
                linehl = "DapBreakpoint",
                numhl = "DapBreakpoint",
            })

            vim.fn.sign_define("DapStopped", {
                text = "🔴",
                texthl = "yellow",
                linehl = "DapBreakpoint",
                numhl = "DapBreakpoint",
            })
            vim.fn.sign_define("DapBreakpointRejected", {
                text = "⭕",
                texthl = "DapStoppedSymbol",
                linehl = "DapBreakpoint",
                numhl = "DapBreakpoint",
            })
            -- default configuration
            dapui.setup()
        end,
        event = "VeryLazy",
    },
}
