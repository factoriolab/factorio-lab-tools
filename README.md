# Factorio Lab Tools

This repository contains a tool used for generating JSON data and icons for the Factorio Lab calculator. It is forked from [this repository](https://bitbucket.org/hhrhhr/factorio-lab-tools) by Dmitry Zaitsev (@hhrhhr).

## Prepare

1. Download and unpack _tcc-0.9.27-win64-bin.zip_ and _winapi-full-for-0.9.27.zip_ from [http://download.savannah.gnu.org/releases/tinycc](http://download.savannah.gnu.org/releases/tinycc)
2. Update TCC's .def-files:

```shell
cd /d %TCC_DIR%\lib
..\tcc.exe -impdef kernel32.dll
..\tcc.exe -impdef user32.dll
..\tcc.exe -impdef msvcrt.dll
..\tcc.exe -impdef ws2_32.dll
```

## Build on Windows

Edit mass_make.cmd and set:

* `CC` - path to TCC x64 compiler
* `V=1` - show full command output
* `DIST` - install path
* `LUAVER` - Lua version (53 or 52f)

Note: _Lua 52f is forked from [https://github.com/Rseding91/Factorio-Lua](https://github.com/Rseding91/Factorio-Lua)_

## Usage

Build (or download ready package from [Downloads](https://bitbucket.org/hhrhhr/factorio-lab-tools/downloads/) )

```shell
Usage: [lua-lab/]factorio_data_dump.lua [-h] [-g <gamedir>] [-m <moddir>]
                              [-s <iconsize>] [-f <suffix>] [-n] [-i]
                              [-l <language>] [-c]
                              [--factorio_lab_hacks] [-b] [-v] [-d]
                              <command> ...

Data exporter for Factorio.

Options:
   -h, --help                show this help message and exit
   -v, --verbose             more verbose (try -vvv)
   -g, --gamedir <gamedir>   game location (default: .)
   -m, --moddir <moddir>     override mods location
   -s, --iconsize <iconsize> icon size (default: 32)
   -f, --suffix <suffix>     a string that is added to the file name (default: "")
   -n, --nomods              disable mods
   -i, --noimage             disable image generation
   -l, --language <language> select localization (default: en)
   -c, --clear               clear unneded fields in data.raw
   -b, --browse              * open browser (only with 'calc' command)
   -d, --debug               * start mobdebug

Commands:
   dump                  export data.raw from game and save it
   export                export data.raw for Factorio Lab
   demo                  export data.raw for demo page generation (with demo.lua)
   web                   * just start web server

* - not implemented
```

### Issues

* Only unpacked modifications are supported.
* The selection of the used modifications is exported from the game, as well as their settings (so first start the game, select the mods, configure them as you wish and exit the game).
* Some recipes show unsupported machines (e.g. "uranium ore" should not be mined with a "burner mining drill")
