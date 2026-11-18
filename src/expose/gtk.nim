## Minimal hand-written bindings for GLib/GObject, GIO, GTK 3, GDK, Pango and
## gtk-layer-shell: only what the overlay uses, under the C names. Linked
## by soname so no -devel packages are needed beyond what the Nim compiler
## itself requires.

import ./[cairo, wayland]

{.passL: "-l:libgobject-2.0.so.0 -l:libglib-2.0.so.0 -l:libgio-2.0.so.0".}
{.passL: "-l:libgtk-3.so.0 -l:libgdk-3.so.0 -l:libgtk-layer-shell.so.0".}
{.passL: "-l:libpango-1.0.so.0 -l:libpangocairo-1.0.so.0".}

type
  gboolean* = cint
  GCallback* = pointer
  GtkWidget* = ptr object
  GdkEvent* = ptr object
  GdkScreen* = ptr object
  GdkVisual* = ptr object
  GdkDisplay* = ptr object
  GdkWindow* = ptr object
  GIcon* = ptr object
  GAppInfo* = ptr object
  GtkIconTheme* = ptr object
  GtkIconInfo* = ptr object
  PangoLayout* = ptr object
  PangoFontDescription* = ptr object

const
  GTK_WINDOW_TOPLEVEL* = cint(0)
  GDK_POINTER_MOTION_MASK* = cint(1 shl 2)
  GDK_BUTTON_PRESS_MASK* = cint(1 shl 8)
  GDK_BUTTON_RELEASE_MASK* = cint(1 shl 9)
  GDK_KEY_PRESS_MASK* = cint(1 shl 10)
  GDK_LEAVE_NOTIFY_MASK* = cint(1 shl 13)
  GTK_ICON_LOOKUP_FORCE_SIZE* = cint(1 shl 4)
  PANGO_SCALE* = 1024
  PANGO_ELLIPSIZE_END* = cint(3)
  PANGO_ALIGN_CENTER* = cint(1)
  PANGO_WEIGHT_BOLD* = cint(700)
  GTK_LAYER_SHELL_EDGE_LEFT* = cint(0)
  GTK_LAYER_SHELL_EDGE_RIGHT* = cint(1)
  GTK_LAYER_SHELL_EDGE_TOP* = cint(2)
  GTK_LAYER_SHELL_EDGE_BOTTOM* = cint(3)
  GTK_LAYER_SHELL_LAYER_OVERLAY* = cint(3)
  GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE* = cint(1)
  GDK_KEY_Tab* = cuint(0xff09)
  GDK_KEY_ISO_Left_Tab* = cuint(0xfe20)
  GDK_KEY_Return* = cuint(0xff0d)
  GDK_KEY_KP_Enter* = cuint(0xff8d)
  GDK_KEY_Escape* = cuint(0xff1b)
  GDK_KEY_Delete* = cuint(0xffff)
  GDK_KEY_Left* = cuint(0xff51)
  GDK_KEY_Up* = cuint(0xff52)
  GDK_KEY_Right* = cuint(0xff53)
  GDK_KEY_Down* = cuint(0xff54)

{.push importc, cdecl.}
proc g_free*(mem: pointer)
proc g_object_unref*(obj: pointer)
proc g_signal_connect_data*(instance: pointer, signal: cstring,
    handler: GCallback, data, destroyData: pointer, flags: cint): culong
proc g_idle_add*(function: proc (data: pointer): gboolean {.cdecl.},
    data: pointer): cuint
proc g_desktop_app_info_new*(desktopId: cstring): GAppInfo
proc g_app_info_get_icon*(info: GAppInfo): GIcon
proc g_themed_icon_new*(name: cstring): GIcon

proc gtk_init*(argc: ptr cint, argv: pointer)
proc gtk_main*()
proc gtk_main_quit*()
proc gtk_window_new*(kind: cint): GtkWidget
proc gtk_window_set_title*(window: GtkWidget, title: cstring)
proc gtk_container_add*(container, widget: GtkWidget)
proc gtk_drawing_area_new*(): GtkWidget
proc gtk_widget_add_events*(widget: GtkWidget, events: cint)
proc gtk_widget_set_can_focus*(widget: GtkWidget, canFocus: gboolean)
proc gtk_widget_grab_focus*(widget: GtkWidget)
proc gtk_widget_show_all*(widget: GtkWidget)
proc gtk_widget_queue_draw*(widget: GtkWidget)
proc gtk_widget_set_app_paintable*(widget: GtkWidget, paintable: gboolean)
proc gtk_widget_set_visual*(widget: GtkWidget, visual: GdkVisual)
proc gtk_widget_get_screen*(widget: GtkWidget): GdkScreen
proc gtk_widget_get_window*(widget: GtkWidget): GdkWindow
proc gtk_widget_get_scale_factor*(widget: GtkWidget): cint
proc gtk_widget_get_allocated_width*(widget: GtkWidget): cint
proc gtk_widget_get_allocated_height*(widget: GtkWidget): cint
proc gtk_widget_create_pango_layout*(widget: GtkWidget,
    text: cstring): PangoLayout
proc gtk_icon_theme_get_default*(): GtkIconTheme
proc gtk_icon_theme_lookup_by_gicon_for_scale*(theme: GtkIconTheme,
    icon: GIcon, size, scale, flags: cint): GtkIconInfo
proc gtk_icon_info_load_surface*(info: GtkIconInfo, forWindow: GdkWindow,
    error: pointer): CairoSurface

proc gdk_screen_get_rgba_visual*(screen: GdkScreen): GdkVisual
proc gdk_display_get_default*(): GdkDisplay
proc gdk_wayland_display_get_wl_display*(display: GdkDisplay): WlDisplay
proc gdk_event_get_coords*(event: GdkEvent, x, y: ptr cdouble): gboolean
proc gdk_event_get_button*(event: GdkEvent, button: ptr cuint): gboolean
proc gdk_event_get_keyval*(event: GdkEvent, keyval: ptr cuint): gboolean

proc pango_layout_set_text*(layout: PangoLayout, text: cstring, length: cint)
proc pango_layout_set_width*(layout: PangoLayout, width: cint)
proc pango_layout_set_ellipsize*(layout: PangoLayout, ellipsize: cint)
proc pango_layout_set_alignment*(layout: PangoLayout, alignment: cint)
proc pango_layout_set_font_description*(layout: PangoLayout,
    desc: PangoFontDescription)
proc pango_layout_get_pixel_size*(layout: PangoLayout, width, height: ptr cint)
proc pango_font_description_from_string*(str: cstring): PangoFontDescription
proc pango_font_description_free*(desc: PangoFontDescription)
proc pango_cairo_show_layout*(cr: Cairo, layout: PangoLayout)

proc gtk_layer_is_supported*(): gboolean
proc gtk_layer_init_for_window*(window: GtkWidget)
proc gtk_layer_set_namespace*(window: GtkWidget, name: cstring)
proc gtk_layer_set_layer*(window: GtkWidget, layer: cint)
proc gtk_layer_set_anchor*(window: GtkWidget, edge: cint, anchor: gboolean)
proc gtk_layer_set_exclusive_zone*(window: GtkWidget, zone: cint)
proc gtk_layer_set_keyboard_mode*(window: GtkWidget, mode: cint)
{.pop.}

proc g_signal_connect*(instance: pointer, signal: cstring, handler: GCallback,
    data: pointer = nil) =
  discard g_signal_connect_data(instance, signal, handler, data, nil, 0)
