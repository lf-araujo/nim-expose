## Minimal cairo bindings (only what nim-expose uses).

import std/math

{.passL: "-l:libcairo.so.2".}

type
  CairoSurface* = ptr object
  Cairo* = ptr object

const
  CAIRO_FORMAT_ARGB32* = cint(0)
  CAIRO_FORMAT_RGB24* = cint(1)
  CAIRO_FILTER_GOOD* = cint(1)
  CAIRO_OPERATOR_SOURCE* = cint(1)
  CAIRO_STATUS_SUCCESS* = cint(0)

{.push importc, cdecl.}
proc cairo_image_surface_create*(format, width, height: cint): CairoSurface
proc cairo_image_surface_create_for_data*(data: pointer, format, width,
    height, stride: cint): CairoSurface
proc cairo_image_surface_get_width*(surface: CairoSurface): cint
proc cairo_image_surface_get_height*(surface: CairoSurface): cint
proc cairo_surface_destroy*(surface: CairoSurface)
proc cairo_surface_status*(surface: CairoSurface): cint
proc cairo_surface_flush*(surface: CairoSurface)
proc cairo_surface_mark_dirty*(surface: CairoSurface)
proc cairo_surface_write_to_png*(surface: CairoSurface,
    filename: cstring): cint
proc cairo_create*(target: CairoSurface): Cairo
proc cairo_destroy*(cr: Cairo)
proc cairo_save*(cr: Cairo)
proc cairo_restore*(cr: Cairo)
proc cairo_scale*(cr: Cairo, sx, sy: cdouble)
proc cairo_translate*(cr: Cairo, tx, ty: cdouble)
proc cairo_set_operator*(cr: Cairo, op: cint)
proc cairo_set_source_surface*(cr: Cairo, surface: CairoSurface,
    x, y: cdouble)
proc cairo_set_source_rgba*(cr: Cairo, red, green, blue, alpha: cdouble)
proc cairo_pattern_set_filter*(pattern: pointer, filter: cint)
proc cairo_get_source*(cr: Cairo): pointer
proc cairo_paint*(cr: Cairo)
proc cairo_paint_with_alpha*(cr: Cairo, alpha: cdouble)
proc cairo_rectangle*(cr: Cairo, x, y, width, height: cdouble)
proc cairo_arc*(cr: Cairo, xc, yc, radius, angle1, angle2: cdouble)
proc cairo_new_sub_path*(cr: Cairo)
proc cairo_close_path*(cr: Cairo)
proc cairo_move_to*(cr: Cairo, x, y: cdouble)
proc cairo_line_to*(cr: Cairo, x, y: cdouble)
proc cairo_set_line_width*(cr: Cairo, width: cdouble)
proc cairo_fill*(cr: Cairo)
proc cairo_fill_preserve*(cr: Cairo)
proc cairo_stroke*(cr: Cairo)
proc cairo_clip*(cr: Cairo)
{.pop.}

proc roundedRectangle*(cr: Cairo, x, y, width, height, radius: float) =
  ## Adds a rectangle with rounded corners to the current path.
  let r = min(radius, min(width, height) / 2)
  cairo_new_sub_path(cr)
  cairo_arc(cr, x + width - r, y + r, r, -PI / 2, 0)
  cairo_arc(cr, x + width - r, y + height - r, r, 0, PI / 2)
  cairo_arc(cr, x + r, y + height - r, r, PI / 2, PI)
  cairo_arc(cr, x + r, y + r, r, PI, 3 * PI / 2)
  cairo_close_path(cr)
