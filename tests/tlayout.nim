import std/unittest
import ../src/expose/layout

const area = Rect(x: 0, y: 0, width: 1200, height: 600)

suite "layout":
  test "best columns favour wide cells in a wide area":
    check bestColumns(1, 1.6, 1200, 600, 10) == 1
    check bestColumns(4, 1.6, 1200, 600, 10) == 2
    check bestColumns(6, 1.6, 1200, 600, 10) == 3

  test "cells stay inside the area and do not overlap":
    let grid = gridLayout(5, area, 1.6, 10, 10_000)
    check grid.cells.len == 5
    for i, a in grid.cells:
      check a.x >= 0 and a.y >= 0
      check a.x + a.width <= 1200.001 and a.y + a.height <= 600.001
      for j, b in grid.cells:
        if i < j:
          check a.x + a.width <= b.x + 0.001 or b.x + b.width <= a.x + 0.001 or
            a.y + a.height <= b.y + 0.001 or b.y + b.height <= a.y + 0.001

  test "a lone window is capped in width":
    let grid = gridLayout(1, area, 1.6, 10, 400)
    check grid.cells[0].width <= 400.001

  test "hit test":
    let grid = gridLayout(2, area, 1.6, 10, 10_000)
    let c = grid.cells[1]
    check grid.hitTest(c.x + 1, c.y + 1) == 1
    check grid.hitTest(-5, -5) == -1

  test "keyboard movement":
    let grid = gridLayout(5, area, 1.6, 10, 10_000) # 3 + 2
    check grid.columns == 3
    check grid.move(-1, dRight) == 0
    check grid.move(-1, dLeft) == 4
    check grid.move(2, dRight) == 3
    check grid.move(4, dNext) == 0
    check grid.move(0, dDown) == 3
    check grid.move(2, dDown) == 4 # no cell below: last one
    check grid.move(4, dUp) == 1
    check grid.move(1, dUp) == 1

  test "fit within keeps aspect and bottom-aligns":
    let r = fitWithin(200, 100, Rect(x: 0, y: 0, width: 100, height: 100))
    check r.width == 100 and r.height == 50
    check r.y == 50
    let small = fitWithin(20, 10, Rect(x: 0, y: 0, width: 100, height: 100))
    check small.width == 20 # never enlarged past maxScale 1
