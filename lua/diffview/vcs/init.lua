local GitAdapter = require('diffview.vcs.adapters.git').GitAdapter
local HgAdapter = require('diffview.vcs.adapters.hg').HgAdapter
local config = require('diffview.config')
local utils = require('diffview.utils')

local M = {}

---@class vcs.init.get_adapter.Opt
---@field top_indicators string[]?
---@field cmd_ctx vcs.init.get_adapter.Opt.Cmd_Ctx? # Context data from a command call.

---@class vcs.init.get_adapter.Opt.Cmd_Ctx
---@field path_args string[] # Raw path args
---@field cpath string? # Cwd path given by the `-C` flag option

---@param opt vcs.init.get_adapter.Opt
---@return string? err
---@return VCSAdapter? adapter
function M.get_adapter(opt)
  local adapter_kinds = { GitAdapter, HgAdapter }

  if not opt.cmd_ctx then
    opt.cmd_ctx = {}
  end

  for _, kind in ipairs(adapter_kinds) do
    local path_args
    local top_indicators = opt.top_indicators

    if not kind.bootstrap.done then kind.run_bootstrap() end
    if not kind.bootstrap.ok then goto continue end

    if not top_indicators then
      path_args, top_indicators = kind.get_repo_paths(opt.cmd_ctx.path_args, opt.cmd_ctx.cpath)
    end

    local err, toplevel = kind.find_toplevel(top_indicators)

    -- If we failed to run git, then attempt to use the fallback command.
    if err then
      local conf = config.get_config()
      if conf.git_cmd_fallback ~= nil then
        conf["git_cmd"] = conf.git_cmd_fallback
        err, toplevel = kind.find_toplevel(top_indicators)
      end
    end

    if not err then
      -- Create a new adapter instance. Store the resolved path args and the
      -- cpath in the adapter context.
      return kind.create(utils.normalize_path(toplevel), path_args, opt.cmd_ctx.cpath)
    end

    ::continue::
  end

  return "Not a repo (or any parent), or no supported VCS adapter!"
end

return M
