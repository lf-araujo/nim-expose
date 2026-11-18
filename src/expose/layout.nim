## Grid layout and keyboard navigation for the overview. Pure Nim, no GTK,
## so it can be unit-tested.

type
  Rect* = object
    x*, y*, width*, height*: float
  Grid* = object
    columns*, rows*: int
    cells*: seq[Rect] ## One per window, in window order.

func contains*(rect: Rect, x, y: float): bool =
  x >= rect.x and x < rect.x + rect.width and
    y >= rect.y and y < rect.y + rect.height

func bestColumns*(count: int, aspect, width, height, gap: float): int =
  ## The number of columns that makes `count` cells of `aspect`
  ## (width / height) as large as possible in a `width` x `height` area.
  result = 1
  var bestSize = -1.0
  for columns in 1 .. max(count, 1):
    let
      rows = (count + columns - 1) div columns
      cellW = (width - gap * float(columns - 1)) / float(columns)
      cellH = (height - gap * float(rows - 1)) / float(rows)
      size = min(cellW, cellH * aspect)
    if size > bestSize:
      bestSize = size
      result = columns

func gridLayout*(count: int, area: Rect, aspect, gap, maxCellWidth: float):
    Grid =
  ## Lays `count` cells out in rows, centred in `area`, each cell close to
  ## `aspect` and no wider than `maxCellWidth`. The last row is centred on
  ## its own.
  if count <= 0:
    return
  let columns = bestColumns(count, aspect, area.width, area.height, gap)
  let rows = (count + columns - 1) div columns
  var
    cellW = (area.width - gap * float(columns - 1)) / float(columns)
    cellH = (area.height - gap * float(rows - 1)) / float(rows)
  cellW = min(cellW, min(cellH * aspect, maxCellWidth))
  cellH = min(cellH, cellW / aspect)
  result.columns = columns
  result.rows = rows
  let
    gridH = float(rows) * cellH + float(rows - 1) * gap
    y0 = area.y + (area.height - gridH) / 2
  for i in 0 ..< count:
    let
      row = i div columns
      inRow = min(columns, count - row * columns)
      rowW = float(inRow) * cellW + float(inRow - 1) * gap
      x0 = area.x + (area.width - rowW) / 2
    result.cells.add Rect(x: x0 + float(i mod columns) * (cellW + gap),
        y: y0 + float(row) * (cellH + gap), width: cellW, height: cellH)

func hitTest*(grid: Grid, x, y: float): int =
  ## Index of the cell under (x, y), or -1.
  result = -1
  for i, cell in grid.cells:
    if cell.contains(x, y):
      result = i

type Direction* = enum
  dLeft, dRight, dUp, dDown, dNext, dPrevious

func move*(grid: Grid, selected: int, direction: Direction): int =
  ## The cell selected after moving from `selected` (-1: none yet).
  let count = grid.cells.len
  if count == 0:
    return -1
  if selected < 0 or selected >= count:
    return (if direction in {dLeft, dUp, dPrevious}: count - 1 else: 0)
  case direction
  of dNext, dRight: (selected + 1) mod count
  of dPrevious, dLeft: (selected - 1 + count) mod count
  of dDown:
    if selected + grid.columns < count: selected + grid.columns
    elif selected div grid.columns < grid.rows - 1: count - 1
    else: selected
  of dUp:
    if selected - grid.columns >= 0: selected - grid.columns else: selected

func fitWithin*(width, height: float, bounds: Rect, maxScale = 1.0): Rect =
  ## `width` x `height` scaled to fit `bounds` (never above `maxScale`),
  ## centred horizontally and resting on the bottom edge.
  let scale = min(maxScale, min(bounds.width / width, bounds.height / height))
  result.width = width * scale
  result.height = height * scale
  result.x = bounds.x + (bounds.width - result.width) / 2
  result.y = bounds.y + bounds.height - result.height
