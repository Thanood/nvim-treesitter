local fn = vim.fn
local utils = require'nvim-treesitter.utils'

local M = {}

function M.select_mkdir_cmd(directory, cwd, info_msg)
  if fn.has('win32') == 1 then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'mkdir', directory},
	cwd = cwd,
      },
      info = info_msg,
      err = "Could not create "..directory,
    }
  else
    return {
      cmd = 'mkdir',
      opts = {
        args = { directory },
	cwd = cwd,
      },
      info = info_msg,
      err = "Could not create "..directory,
    }
  end
end

function M.select_rm_file_cmd(file, info_msg)
  if fn.has('win32') == 1 then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'if', 'exist', file, 'del', file },
      },
      info = info_msg,
      err = "Could not delete "..file,
    }
  else
    return {
      cmd = 'rm',
      opts = {
        args = { file },
      },
      info = info_msg,
      err = "Could not delete "..file,
    }
  end
end

function M.select_executable(executables)
  return vim.tbl_filter(function(c) return c ~= vim.NIL and fn.executable(c) == 1 end, executables)[1]
end

function M.select_compiler_args(repo)
  local args = {
        '-o',
        'parser.so',
        '-I./src',
        repo.files,
        '-shared',
        '-Os',
        '-lstdc++',
  }
  if fn.has('win32') == 0 then
    table.insert(args, '-fPIC')
  end
  return args
end

function M.select_install_rm_cmd(cache_folder, project_name)
  if fn.has('win32') == 1 then
    local dir = cache_folder ..'\\'.. project_name
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'if', 'exist', dir, 'rmdir', '/s', '/q', dir },
      }
    }
  else
    return {
      cmd = 'rm',
      opts = {
        args = { '-rf', cache_folder..'/'..project_name },
      }
    }
  end
end

function M.select_mv_cmd(from, to, cwd)
  if fn.has('win32') == 1 then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'move', '/Y', from, to },
        cwd = cwd,
      }
    }
  else
    return {
      cmd = 'mv',
      opts = {
        args = { from, to },
        cwd = cwd,
      },
    }
  end
end

function M.select_download_commands(repo, project_name, cache_folder, revision)
  local is_windows = fn.has('win32') == 1

  revision = revision or repo.branch or "master"

  local has_tar = vim.fn.executable('tar') == 1 and not is_windows
  if has_tar and vim.fn.executable('curl') == 1 and repo.url:find("github.com", 1, true) then

    local path_sep = utils.get_path_sep()
    return {
      M.select_install_rm_cmd(cache_folder, project_name..'-tmp'),
      {
        cmd = 'curl',
        info = 'Downloading...',
        err = 'Error during download, please verify your internet connection',
        opts = {
          args = {
            '-L', -- follow redirects
            repo.url.."/archive/"..revision..".tar.gz",
            '--output',
            project_name..".tar.gz"
          },
          cwd = cache_folder,
        },
      },
      M.select_mkdir_cmd(project_name..'-tmp', cache_folder, 'Creating temporary directory'),
      {
        cmd = 'tar',
        info = 'Extracting...',
        err = 'Error during tarball extraction.',
        opts = {
          args = {
            '-xvf',
            project_name..".tar.gz",
            '-C',
            project_name..'-tmp',
          },
          cwd = cache_folder,
        },
      },
      M.select_rm_file_cmd(cache_folder..path_sep..project_name..".tar.gz"),
      M.select_mv_cmd(utils.join_path(project_name..'-tmp', repo.url:match('[^/]-$')..'-'..revision),
                    project_name,
                    cache_folder),
      M.select_install_rm_cmd(cache_folder, project_name..'-tmp')
    }
  else
    local git_folder
    if is_windows then
      git_folder = cache_folder ..'\\'.. project_name
    else
      git_folder = cache_folder ..'/'.. project_name
    end

    local clone_error = 'Error during download, please verify your internet connection'
    if is_windows then
      clone_error = clone_error .. ". If on Windows you may need to enable Developer mode"
    end

    return {
      {
        cmd = 'git',
        info = 'Downloading...',
        err = clone_error,
        opts = {
          args = {
            'clone',
            '-c', 'core.symlinks=true',
            '--single-branch',
            '--branch', repo.branch or 'master',
            repo.url,
            project_name
          },
          cwd = cache_folder,
        },
      },
      {
        cmd = 'git',
        info = 'Checking out locked revision',
        err = 'Error while checking out revision',
        opts = {
          args = {
            '-c', 'core.symlinks=true',
            'checkout', revision
          },
          cwd = git_folder
        }
      }
    }
  end
end

return M
