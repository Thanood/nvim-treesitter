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

function M.select_compiler_args(repo, compiler)
  if (string.match(compiler, 'cl$') or string.match(compiler, 'cl.exe$')) then
    return {
      '/Fe:',
      'parser.so',
      '/Isrc',
      repo.files,
      '-Os',
      '/LD',
    }
  else
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

  local can_use_tar = vim.fn.executable('tar') == 1 and vim.fn.executable('curl') == 1
  local is_github_or_gitlab = repo.url:find("github.com", 1, true) or repo.url:find("gitlab.com", 1, true)
  local is_windows = fn.has('win32') == 1

  revision = revision or repo.branch or "master"

  if can_use_tar and is_github_or_gitlab and not is_windows then

    local path_sep = utils.get_path_sep()
    local url = repo.url:gsub('.git$', '')

    return {
      M.select_install_rm_cmd(cache_folder, project_name..'-tmp'),
      {
        cmd = 'curl',
        info = 'Downloading...',
        err = 'Error during download, please verify your internet connection',
        opts = {
          args = {
            '-L', -- follow redirects
            is_github_or_gitlab and url.."/archive/"..revision..".tar.gz"
                      or url.."/-/archive/"..revision.."/"..project_name.."-"..revision..".tar.gz",
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
      M.select_mv_cmd(utils.join_path(project_name..'-tmp', url:match('[^/]-$')..'-'..revision),
        project_name,
        cache_folder),
      M.select_install_rm_cmd(cache_folder, project_name..'-tmp')
    }
  else
    local git_folder = utils.join_path(cache_folder, project_name)
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
            'checkout', revision
          },
          cwd = git_folder
        }
      }
    }
  end
end

function M.make_directory_change_for_command(dir, command)
  if fn.has('win32') == 1 then
    return string.format("pushd %s & %s & popd", dir, command)
  else
    return string.format("cd %s;\n %s", dir, command)
  end
end

return M
