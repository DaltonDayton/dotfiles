return {
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {
      filetypes = { "*" },
      options = {
        parsers = {
          css = true,
          tailwind = { enable = true },
        },
      },
    },
    keys = {
      {
        "<leader>ur",
        function()
          require("colorizer.buffer").reset_cache()
          require("colorizer").attach_to_buffer(0)
        end,
        desc = "Reload colorizer (after theme switch)",
      },
    },
  },
}
