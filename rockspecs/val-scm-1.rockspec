package = 'val'
version = 'scm-1'
source  = {
    url    = 'git://github.com/moonlibs/val.git',
    branch = 'master',
}
description = {
    summary  = "Package for complex structure validation and transformation",
    homepage = 'https://github.com/moonlibs/val.git',
    license  = 'BSD',
}
dependencies = {
    'lua >= 5.1'
}
build = {
    type = 'builtin',
    modules = {
        ['val'] = 'val.lua';
    }
}

-- vim: syntax=lua
