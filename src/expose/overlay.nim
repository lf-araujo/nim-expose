## The overview itself: a full-screen layer-shell surface showing every open
## window as a thumbnail, drawn with cairo in a single GtkDrawingArea.
##
## Mouse: click a window to switch to it (labwc also switches to its
## workspace), click its X or middle-click it to close it, click elsewhere
## to dismiss. Keyboard: arrows/Tab to move, Enter to switch, Delete to
## close, Esc to dismiss.

import std/[math, strutils, tables]
import ./[cairo, capture, gtk, layout, wayland, windows]

const
  margin = 48.0
  headerHeight = 36.0
  gap = 24.0
  cellAspect = 1.35 ## Width / height of a cell, thumbnail plus title.
  maxCellWidth = 440.0
  cellPadding = 10.0
  titleHeight = 26.0
  iconSize = 32
  closeRadius = 11.0
  captureWidth = 640 ## Thumbnails are kept at most this wide.
  backdropAlpha = 0.88
  minimizedAlpha = 0.45

type
  Overlay = ref object
    list: WindowList
    window, area: GtkWidget
    grid: Grid
    selected: Window
    icons: Table[string, CairoSurface]
    capturing: seq[Window]
    closeRequested: bool
    lastCount: int

proc toOverlay(data: pointer): Overlay = cast[Overlay](data)

proc redraw(overlay: Overlay) =
  gtk_widget_queue_draw(overlay.area)

proc dismiss(overlay: Overlay) =
  gtk_main_quit()

# --- Captures ---------------------------------------------------------------

proc onCaptured(data: pointer, window: Window, ok: bool) =
  let overlay = data.toOverlay
  let pos = overlay.capturing.find(window)
  if pos >= 0:
    overlay.capturing.delete(pos)
  overlay.redraw()

proc captureMissing(overlay: Overlay) =
  for window in overlay.list.windows:
    if window.thumbnail == nil and window notin overlay.capturing:
      overlay.capturing.add window
      capture(overlay.list, window, captureWidth, onCaptured,
          cast[pointer](overlay))

proc onWindowsChanged(data: pointer) =
  let overlay = data.toOverlay
  let count = overlay.list.windows.len
  # A window appearing after a close request is usually a "save changes?"
  # dialog; get out of its way.
  if overlay.closeRequested and count > overlay.lastCount:
    overlay.dismiss()
  overlay.lastCount = count
  if overlay.selected != nil and overlay.selected notin overlay.list.windows:
    overlay.selected = nil
  overlay.captureMissing()
  overlay.redraw()

# --- Icons ------------------------------------------------------------------

proc loadIcon(overlay: Overlay, gicon: GIcon): CairoSurface =
  let info = gtk_icon_theme_lookup_by_gicon_for_scale(
      gtk_icon_theme_get_default(), gicon, iconSize,
      gtk_widget_get_scale_factor(overlay.area), GTK_ICON_LOOKUP_FORCE_SIZE)
  if info != nil:
    result = gtk_icon_info_load_surface(info,
        gtk_widget_get_window(overlay.area), nil)
    g_object_unref(info)

proc icon(overlay: Overlay, appId: string): CairoSurface =
  ## The app's icon from its desktop file, else a themed icon named after
  ## the app ID, else a generic one. Cached per app ID.
  if appId in overlay.icons:
    return overlay.icons[appId]
  for id in [appId, appId.toLowerAscii()]:
    if result == nil and id.len > 0:
      let info = g_desktop_app_info_new(cstring(id & ".desktop"))
      if info != nil:
        let gicon = g_app_info_get_icon(info)
        if gicon != nil:
          result = overlay.loadIcon(gicon)
        g_object_unref(info)
  for name in [appId, appId.toLowerAscii(), "application-x-executable"]:
    if result == nil and name.len > 0:
      let gicon = g_themed_icon_new(cstring(name))
      result = overlay.loadIcon(gicon)
      g_object_unref(gicon)
  overlay.icons[appId] = result

# --- Geometry ---------------------------------------------------------------

proc updateGrid(overlay: Overlay) =
  let
    width = float(gtk_widget_get_allocated_width(overlay.area))
    height = float(gtk_widget_get_allocated_height(overlay.area))
    area = Rect(x: margin, y: margin + headerHeight,
        width: width - 2 * margin,
        height: height - 2 * margin - headerHeight)
  overlay.grid = gridLayout(overlay.list.windows.len, area, cellAspect, gap,
      maxCellWidth)

proc thumbBounds(cell: Rect): Rect =
  Rect(x: cell.x + cellPadding, y: cell.y + cellPadding,
      width: cell.width - 2 * cellPadding,
      height: cell.height - 2 * cellPadding - titleHeight)

proc thumbRect(window: Window, cell: Rect): Rect =
  ## Where the window's thumbnail (or placeholder) is drawn in its cell.
  let bounds = thumbBounds(cell)
  if window.thumbnail != nil:
    let surface = cast[CairoSurface](window.thumbnail)
    fitWithin(float(cairo_image_surface_get_width(surface)),
        float(cairo_image_surface_get_height(surface)), bounds)
  else:
    fitWithin(16, 10, bounds, maxScale = 1000)

proc closeCenter(thumb: Rect): (float, float) =
  (thumb.x + thumb.width, thumb.y)

proc onCloseButton(window: Window, cell: Rect, x, y: float): bool =
  let (cx, cy) = closeCenter(thumbRect(window, cell))
  let dx = x - cx
  let dy = y - cy
  dx * dx + dy * dy <= (closeRadius + 3) * (closeRadius + 3)

# --- Drawing ----------------------------------------------------------------

proc drawText(overlay: Overlay, cr: Cairo, text: string, x, y, width: float,
    alpha: float, bold = false) =
  let layout = gtk_widget_create_pango_layout(overlay.area, cstring(text))
  pango_layout_set_width(layout, cint(width * PANGO_SCALE))
  pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END)
  pango_layout_set_alignment(layout, PANGO_ALIGN_CENTER)
  if bold:
    let font = pango_font_description_from_string("Bold")
    pango_layout_set_font_description(layout, font)
    pango_font_description_free(font)
  cairo_set_source_rgba(cr, 1, 1, 1, alpha)
  cairo_move_to(cr, x, y)
  pango_cairo_show_layout(cr, layout)
  g_object_unref(layout)

proc drawSurface(cr: Cairo, surface: CairoSurface, rect: Rect,
    alpha: float) =
  let
    width = float(cairo_image_surface_get_width(surface))
    height = float(cairo_image_surface_get_height(surface))
  cairo_save(cr)
  roundedRectangle(cr, rect.x, rect.y, rect.width, rect.height, 6)
  cairo_clip(cr)
  cairo_translate(cr, rect.x, rect.y)
  cairo_scale(cr, rect.width / width, rect.height / height)
  cairo_set_source_surface(cr, surface, 0, 0)
  cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_GOOD)
  cairo_paint_with_alpha(cr, alpha)
  cairo_restore(cr)

proc drawIcon(cr: Cairo, icon: CairoSurface, x, y: float) =
  if icon != nil:
    cairo_set_source_surface(cr, icon, x, y)
    cairo_paint(cr)

proc drawCloseButton(cr: Cairo, thumb: Rect, hot: bool) =
  let (cx, cy) = closeCenter(thumb)
  cairo_new_sub_path(cr)
  cairo_arc(cr, cx, cy, closeRadius, 0, 2 * PI)
  if hot:
    cairo_set_source_rgba(cr, 0.90, 0.25, 0.22, 1)
  else:
    cairo_set_source_rgba(cr, 0.25, 0.25, 0.25, 0.95)
  cairo_fill_preserve(cr)
  cairo_set_source_rgba(cr, 1, 1, 1, 0.9)
  cairo_set_line_width(cr, 1.5)
  cairo_stroke(cr)
  let d = closeRadius * 0.4
  cairo_move_to(cr, cx - d, cy - d)
  cairo_line_to(cr, cx + d, cy + d)
  cairo_move_to(cr, cx + d, cy - d)
  cairo_line_to(cr, cx - d, cy + d)
  cairo_set_line_width(cr, 2)
  cairo_stroke(cr)

proc drawWindow(overlay: Overlay, cr: Cairo, window: Window, cell: Rect) =
  let
    selected = window == overlay.selected
    thumb = thumbRect(window, cell)
  if selected:
    roundedRectangle(cr, cell.x, cell.y, cell.width, cell.height, 10)
    cairo_set_source_rgba(cr, 1, 1, 1, 0.14)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, 1, 1, 1, 0.55)
    cairo_set_line_width(cr, 2)
    cairo_stroke(cr)
  let alpha = if window.minimized: minimizedAlpha else: 1.0
  let icon = overlay.icon(window.appId)
  if window.thumbnail != nil:
    drawSurface(cr, cast[CairoSurface](window.thumbnail), thumb, alpha)
    drawIcon(cr, icon, thumb.x - iconSize / 4,
        thumb.y + thumb.height - iconSize * 3 / 4)
  else:
    # Not captured (yet): a plain card with the app icon.
    roundedRectangle(cr, thumb.x, thumb.y, thumb.width, thumb.height, 6)
    cairo_set_source_rgba(cr, 1, 1, 1, 0.08)
    cairo_fill(cr)
    drawIcon(cr, icon, thumb.x + (thumb.width - iconSize) / 2,
        thumb.y + (thumb.height - iconSize) / 2)
  var title = window.title
  if window.minimized:
    title.add " (minimized)"
  overlay.drawText(cr, title, cell.x + cellPadding,
      cell.y + cell.height - cellPadding - titleHeight + 4,
      cell.width - 2 * cellPadding, if selected: 1.0 else: 0.85)
  if window.canControl:
    drawCloseButton(cr, thumb, hot = selected)

proc onDraw(widget: GtkWidget, cr: Cairo, data: pointer): gboolean
    {.cdecl.} =
  let overlay = data.toOverlay
  overlay.updateGrid()
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
  cairo_set_source_rgba(cr, 0.06, 0.06, 0.08, backdropAlpha)
  cairo_paint(cr)
  cairo_set_operator(cr, 2) # CAIRO_OPERATOR_OVER
  let
    width = float(gtk_widget_get_allocated_width(widget))
    count = overlay.list.windows.len
    header =
      if count == 0: "No windows"
      elif count == 1: "1 window"
      else: $count & " windows"
  overlay.drawText(cr, header & "   ·   click to switch, × or middle-click " &
      "to close, Esc to dismiss", margin, margin, width - 2 * margin, 0.7)
  for i, window in overlay.list.windows:
    if i < overlay.grid.cells.len:
      overlay.drawWindow(cr, window, overlay.grid.cells[i])

# --- Input ------------------------------------------------------------------

proc windowAt(overlay: Overlay, x, y: float): int =
  overlay.grid.hitTest(x, y)

proc select(overlay: Overlay, index: int) =
  let window =
    if index >= 0 and index < overlay.list.windows.len:
      overlay.list.windows[index]
    else: nil
  if window != overlay.selected:
    overlay.selected = window
    overlay.redraw()

proc closeWindow(overlay: Overlay, window: Window) =
  overlay.closeRequested = true
  overlay.lastCount = overlay.list.windows.len
  overlay.list.close(window)

proc activateWindow(overlay: Overlay, window: Window) =
  overlay.list.activate(window)
  overlay.dismiss()

proc onMotion(widget: GtkWidget, event: GdkEvent, data: pointer): gboolean
    {.cdecl.} =
  let overlay = data.toOverlay
  var x, y: cdouble
  if gdk_event_get_coords(event, addr x, addr y) != 0:
    overlay.select(overlay.windowAt(x, y))

proc onRelease(widget: GtkWidget, event: GdkEvent, data: pointer): gboolean
    {.cdecl.} =
  let overlay = data.toOverlay
  var
    x, y: cdouble
    button: cuint
  discard gdk_event_get_coords(event, addr x, addr y)
  discard gdk_event_get_button(event, addr button)
  let index = overlay.windowAt(x, y)
  if index < 0:
    if button == 1:
      overlay.dismiss()
  else:
    let window = overlay.list.windows[index]
    if button == 2:
      overlay.closeWindow(window)
    elif button == 1:
      if window.onCloseButton(overlay.grid.cells[index], x, y):
        overlay.closeWindow(window)
      else:
        overlay.activateWindow(window)
  result = 1

proc onKey(widget: GtkWidget, event: GdkEvent, data: pointer): gboolean
    {.cdecl.} =
  let overlay = data.toOverlay
  var keyval: cuint
  discard gdk_event_get_keyval(event, addr keyval)
  let current = overlay.list.windows.find(overlay.selected)
  result = 1
  case keyval
  of GDK_KEY_Escape:
    overlay.dismiss()
  of GDK_KEY_Return, GDK_KEY_KP_Enter:
    if overlay.selected != nil:
      overlay.activateWindow(overlay.selected)
    else:
      overlay.dismiss()
  of GDK_KEY_Delete:
    if overlay.selected != nil:
      overlay.closeWindow(overlay.selected)
  of GDK_KEY_Left: overlay.select(overlay.grid.move(current, dLeft))
  of GDK_KEY_Right: overlay.select(overlay.grid.move(current, dRight))
  of GDK_KEY_Up: overlay.select(overlay.grid.move(current, dUp))
  of GDK_KEY_Down: overlay.select(overlay.grid.move(current, dDown))
  of GDK_KEY_Tab: overlay.select(overlay.grid.move(current, dNext))
  of GDK_KEY_ISO_Left_Tab:
    overlay.select(overlay.grid.move(current, dPrevious))
  else:
    result = 0

proc onDestroy(widget: GtkWidget, data: pointer) {.cdecl.} =
  gtk_main_quit()

# --- Setup ------------------------------------------------------------------

proc runOverlay*(): int =
  ## Shows the overview until a window is chosen or it is dismissed.
  ## Returns the process exit code.
  gtk_init(nil, nil)
  if gtk_layer_is_supported() == 0:
    stderr.writeLine "nim-expose: the compositor lacks wlr-layer-shell"
    return 1
  let list = newWindowList(gdk_wayland_display_get_wl_display(
      gdk_display_get_default()))
  let missing = list.missingProtocols()
  if missing.len > 0:
    stderr.writeLine "nim-expose: the compositor lacks " & missing.join(", ")
    return 1

  let overlay = Overlay(list: list, lastCount: list.windows.len)
  GC_ref(overlay)
  let data = cast[pointer](overlay)
  list.onChange = onWindowsChanged
  list.onChangeData = data
  for window in list.windows:
    if window.activated:
      overlay.selected = window

  let window = gtk_window_new(GTK_WINDOW_TOPLEVEL)
  overlay.window = window
  gtk_window_set_title(window, "nim-expose")
  gtk_layer_init_for_window(window)
  gtk_layer_set_namespace(window, "nim-expose")
  gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_OVERLAY)
  for edge in [GTK_LAYER_SHELL_EDGE_LEFT, GTK_LAYER_SHELL_EDGE_RIGHT,
      GTK_LAYER_SHELL_EDGE_TOP, GTK_LAYER_SHELL_EDGE_BOTTOM]:
    gtk_layer_set_anchor(window, edge, 1)
  gtk_layer_set_exclusive_zone(window, -1)
  gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE)
  let visual = gdk_screen_get_rgba_visual(gtk_widget_get_screen(window))
  if visual != nil:
    gtk_widget_set_visual(window, visual)
  gtk_widget_set_app_paintable(window, 1)

  overlay.area = gtk_drawing_area_new()
  gtk_widget_set_can_focus(overlay.area, 1)
  gtk_widget_add_events(overlay.area, GDK_POINTER_MOTION_MASK or
      GDK_BUTTON_PRESS_MASK or GDK_BUTTON_RELEASE_MASK or
      GDK_KEY_PRESS_MASK or GDK_LEAVE_NOTIFY_MASK)
  g_signal_connect(overlay.area, "draw", cast[GCallback](onDraw), data)
  g_signal_connect(overlay.area, "motion-notify-event",
      cast[GCallback](onMotion), data)
  g_signal_connect(overlay.area, "button-release-event",
      cast[GCallback](onRelease), data)
  g_signal_connect(overlay.area, "key-press-event", cast[GCallback](onKey),
      data)
  g_signal_connect(window, "destroy", cast[GCallback](onDestroy))
  gtk_container_add(window, overlay.area)
  gtk_widget_show_all(window)
  gtk_widget_grab_focus(overlay.area)

  overlay.captureMissing()
  gtk_main()
  0
