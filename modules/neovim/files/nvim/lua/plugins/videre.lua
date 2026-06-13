return {
  {
    "Owen-Dechow/videre.nvim",
    cmd = "Videre",
    dependencies = {
      "Owen-Dechow/graph_view_yaml_parser",
      "Owen-Dechow/graph_view_toml_parser",
      "a-usr/xml2lua.nvim",
    },
    keys = {
      { "<leader>uv", "<cmd>Videre<cr>", desc = "Videre (graph view current file)" },
    },
    opts = {
      box_style = "rounded", -- match winborder
    },
  },
}
