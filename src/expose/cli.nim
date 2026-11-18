## Command-line modes for testing without the overlay:
##   --list        print the windows the compositor reports
##   --dump DIR    capture every window into DIR/<n>.png

import std/[os, strformat, strutils]
import ./[cairo, capture, wayland, windows]

var pending = 0

proc onCaptured(data: pointer, window: Window, ok: bool) =
  dec pending
  if not ok:
    stderr.writeLine &"capture failed: {window.title}"

proc connect(): WindowList =
  let display = wl_display_connect(nil)
  if display == nil:
    quit("cannot connect to the Wayland display", 1)
  result = newWindowList(display)
  let missing = result.missingProtocols()
  if missing.len > 0:
    for name in missing:
      stderr.writeLine "compositor lacks " & name
    quit(1)

proc listWindows*() =
  let list = connect()
  for i, window in list.windows:
    var flags = ""
    if window.minimized: flags.add " minimized"
    if window.activated: flags.add " active"
    if not window.canControl: flags.add " unpaired"
    echo &"{i}\t{window.appId}\t{window.title}\t[{flags.strip}]"

proc dumpWindows*(dir: string) =
  let list = connect()
  createDir(dir)
  for window in list.windows:
    inc pending
    capture(list, window, 640, onCaptured)
  while pending > 0 and wl_display_dispatch(list.display) >= 0:
    discard
  for i, window in list.windows:
    if window.thumbnail != nil:
      let
        surface = cast[CairoSurface](window.thumbnail)
        path = dir / &"{i}.png"
      discard cairo_surface_write_to_png(surface, cstring(path))
      echo &"{path}\t{cairo_image_surface_get_width(surface)}x" &
        &"{cairo_image_surface_get_height(surface)}\t{window.title}"
