# Package

version = "0.1.0"
author = "Luis De Araujo"
description = "Window overview (Exposé) for labwc, as a separate program"
license = "MIT"
srcDir = "src"
bin = @["nim_expose"]
namedBin["nim_expose"] = "nim-expose"
installDirs = @["expose"]

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run the unit tests":
  exec "nim c -r --hints:off -o:build/tlayout tests/tlayout.nim"

task desktop, "Install the menu entry (~/.local/share/applications)":
  let dir = getEnv("HOME") & "/.local/share/applications"
  mkDir dir
  # The session's PATH does not include ~/.nimble/bin, so use the full path.
  let entry = readFile("data/nim-expose.desktop").replace("@BINDIR@",
    getEnv("HOME") & "/.nimble/bin")
  writeFile(dir & "/nim-expose.desktop", entry)
  echo "Installed " & dir & "/nim-expose.desktop"
