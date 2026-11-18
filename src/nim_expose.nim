## nim-expose: a window overview for labwc (and other wlroots compositors
## with the same protocols), running as a separate program.
##
## Usage:
##   nim-expose          show the overview; if it is already showing, close
##                       it (so one keybinding toggles it)
##   nim-expose --list   print the windows the compositor reports
##   nim-expose --dump DIR
##                       save a thumbnail of every window to DIR

import std/[os, posix, strutils]
import expose/[cli, overlay]

proc pidFile(): string =
  getEnv("XDG_RUNTIME_DIR", getTempDir()) / "nim-expose.pid"

proc closeRunningInstance(): bool =
  ## If an overview is already showing, asks it to quit and returns true.
  try:
    let pid = Pid(parseInt(readFile(pidFile()).strip()))
    if pid != getpid() and kill(pid, 0) == 0 and
        readFile("/proc/" & $pid & "/comm").strip() == "nim-expose":
      result = kill(pid, SIGTERM) == 0
  except IOError, OSError, ValueError:
    discard

proc main(): int =
  let args = commandLineParams()
  if args.len >= 1 and args[0] == "--list":
    listWindows()
  elif args.len >= 2 and args[0] == "--dump":
    dumpWindows(args[1])
  elif args.len > 0:
    stderr.writeLine "usage: nim-expose [--list | --dump DIR]"
    result = 2
  elif not closeRunningInstance():
    writeFile(pidFile(), $getpid())
    result = runOverlay()
    try:
      if readFile(pidFile()).strip() == $getpid():
        removeFile(pidFile())
    except IOError, OSError:
      discard

quit(main())
