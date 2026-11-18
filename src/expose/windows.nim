## The list of open windows, as seen through two protocols:
##
## - ext-foreign-toplevel-list: a stable handle per window, needed to
##   capture its contents.
## - wlr-foreign-toplevel-management: minimized/active state, and the
##   requests to activate or close a window.
##
## The two protocols do not share an ID, so their handles are paired by app
## ID and title, in the order the compositor announces them. labwc creates
## both handles for a window at the same moment, so equal titles (e.g. three
## "Recent Documents" windows) still pair up in the right order.

import ./wayland

type
  Window* = ref object
    list: WindowList
    ext*: ExtToplevel
    wlr: WlrEntry
    title*, appId*, identifier*: string
    closed*: bool
    thumbnail*: pointer ## A cairo image surface owned by the capture code.
  WlrEntry = ref object
    list: WindowList
    handle: WlrToplevel
    title, appId: string
    minimized, activated: bool
    window: Window
    closed: bool
  WindowList* = ref object
    display*: WlDisplay
    registry: WlRegistry
    seat*: WlSeat
    shm*: WlShm
    extList: ExtToplevelList
    wlrManager: WlrToplevelManager
    sourceManager*: ExtToplevelSourceManager
    copyManager*: ExtCopyCaptureManager
    windows*: seq[Window] ## Open windows, oldest first.
    unpaired: seq[WlrEntry]
    onChange*: proc (data: pointer) {.nimcall.}
      ## Called after windows are added, removed or change state.
    onChangeData*: pointer

func minimized*(window: Window): bool =
  window.wlr != nil and window.wlr.minimized

func activated*(window: Window): bool =
  window.wlr != nil and window.wlr.activated

func canControl*(window: Window): bool =
  ## Whether the window can be activated or closed (it is paired).
  window.wlr != nil

proc activate*(list: WindowList, window: Window) =
  if window.wlr != nil and list.seat != nil:
    zwlr_foreign_toplevel_handle_v1_activate(window.wlr.handle, list.seat)
    discard wl_display_flush(list.display)

proc close*(list: WindowList, window: Window) =
  if window.wlr != nil:
    zwlr_foreign_toplevel_handle_v1_close(window.wlr.handle)
    discard wl_display_flush(list.display)

proc changed(list: WindowList) =
  if list.onChange != nil:
    list.onChange(list.onChangeData)

proc pair(list: WindowList) =
  ## Pairs every unpaired window with the first unpaired wlr handle that
  ## has the same app ID and title.
  for window in list.windows:
    if window.wlr == nil and not window.closed:
      var i = 0
      while i < list.unpaired.len:
        let entry = list.unpaired[i]
        if entry.appId == window.appId and entry.title == window.title:
          window.wlr = entry
          entry.window = window
          list.unpaired.delete(i)
          i = list.unpaired.len
        else:
          inc i

# --- ext-foreign-toplevel-list ----------------------------------------------

proc extDone(data: pointer, toplevel: ExtToplevel) {.cdecl.} =
  let list = cast[Window](data).list
  list.pair()
  list.changed()

proc extClosed(data: pointer, toplevel: ExtToplevel) {.cdecl.} =
  let
    window = cast[Window](data)
    list = window.list
  window.closed = true
  let pos = list.windows.find(window)
  if pos >= 0:
    list.windows.delete(pos)
  list.changed()
  ext_foreign_toplevel_handle_v1_destroy(toplevel)
  GC_unref(window)

proc extTitle(data: pointer, toplevel: ExtToplevel, title: cstring)
    {.cdecl.} =
  cast[Window](data).title = $title

proc extAppId(data: pointer, toplevel: ExtToplevel, appId: cstring)
    {.cdecl.} =
  cast[Window](data).appId = $appId

proc extIdentifier(data: pointer, toplevel: ExtToplevel,
    identifier: cstring) {.cdecl.} =
  cast[Window](data).identifier = $identifier

var extToplevelListener = ExtToplevelListener(closed: extClosed,
    done: extDone, title: extTitle, app_id: extAppId,
    identifier: extIdentifier)

proc extNewToplevel(data: pointer, extList: ExtToplevelList,
    toplevel: ExtToplevel) {.cdecl.} =
  let
    list = cast[WindowList](data)
    window = Window(list: list, ext: toplevel)
  GC_ref(window)
  list.windows.add window
  discard ext_foreign_toplevel_handle_v1_add_listener(toplevel,
      addr extToplevelListener, cast[pointer](window))

proc extFinished(data: pointer, extList: ExtToplevelList) {.cdecl.} =
  discard

var extListListener = ExtToplevelListListener(toplevel: extNewToplevel,
    finished: extFinished)

# --- wlr-foreign-toplevel-management ----------------------------------------

proc wlrTitle(data: pointer, toplevel: WlrToplevel, title: cstring)
    {.cdecl.} =
  cast[WlrEntry](data).title = $title

proc wlrAppId(data: pointer, toplevel: WlrToplevel, appId: cstring)
    {.cdecl.} =
  cast[WlrEntry](data).appId = $appId

proc wlrOutput(data: pointer, toplevel: WlrToplevel, output: WlOutput)
    {.cdecl.} =
  discard

proc wlrState(data: pointer, toplevel: WlrToplevel, state: ptr WlArray)
    {.cdecl.} =
  let entry = cast[WlrEntry](data)
  entry.minimized = false
  entry.activated = false
  for value in uint32Items(state):
    if value == WLR_STATE_MINIMIZED:
      entry.minimized = true
    elif value == WLR_STATE_ACTIVATED:
      entry.activated = true

proc wlrDone(data: pointer, toplevel: WlrToplevel) {.cdecl.} =
  let list = cast[WlrEntry](data).list
  list.pair()
  list.changed()

proc wlrClosed(data: pointer, toplevel: WlrToplevel) {.cdecl.} =
  let
    entry = cast[WlrEntry](data)
    list = entry.list
  entry.closed = true
  if entry.window != nil:
    entry.window.wlr = nil
  let pos = list.unpaired.find(entry)
  if pos >= 0:
    list.unpaired.delete(pos)
  zwlr_foreign_toplevel_handle_v1_destroy(toplevel)
  GC_unref(entry)

proc wlrParent(data: pointer, toplevel, parent: WlrToplevel) {.cdecl.} =
  discard

var wlrToplevelListener = WlrToplevelListener(title: wlrTitle,
    app_id: wlrAppId, output_enter: wlrOutput, output_leave: wlrOutput,
    state: wlrState, done: wlrDone, closed: wlrClosed, parent: wlrParent)

proc wlrNewToplevel(data: pointer, manager: WlrToplevelManager,
    toplevel: WlrToplevel) {.cdecl.} =
  let
    list = cast[WindowList](data)
    entry = WlrEntry(list: list, handle: toplevel)
  GC_ref(entry)
  list.unpaired.add entry
  discard zwlr_foreign_toplevel_handle_v1_add_listener(toplevel,
      addr wlrToplevelListener, cast[pointer](entry))

proc wlrFinished(data: pointer, manager: WlrToplevelManager) {.cdecl.} =
  discard

var wlrManagerListener = WlrToplevelManagerListener(
    toplevel: wlrNewToplevel, finished: wlrFinished)

# --- Registry -----------------------------------------------------------------

proc registryGlobal(data: pointer, registry: WlRegistry, name: uint32,
    iface: cstring, version: uint32) {.cdecl.} =
  let list = cast[WindowList](data)
  case $iface
  of "wl_seat":
    if list.seat == nil:
      list.seat = cast[WlSeat](wl_registry_bind(registry, name,
          addr wl_seat_interface, 1))
  of "wl_shm":
    list.shm = cast[WlShm](wl_registry_bind(registry, name,
        addr wl_shm_interface, 1))
  of "ext_foreign_toplevel_list_v1":
    list.extList = cast[ExtToplevelList](wl_registry_bind(registry, name,
        addr ext_foreign_toplevel_list_v1_interface, 1))
    discard ext_foreign_toplevel_list_v1_add_listener(list.extList,
        addr extListListener, data)
  of "zwlr_foreign_toplevel_manager_v1":
    list.wlrManager = cast[WlrToplevelManager](wl_registry_bind(registry,
        name, addr zwlr_foreign_toplevel_manager_v1_interface,
        min(version, 3)))
    discard zwlr_foreign_toplevel_manager_v1_add_listener(list.wlrManager,
        addr wlrManagerListener, data)
  of "ext_foreign_toplevel_image_capture_source_manager_v1":
    list.sourceManager = cast[ExtToplevelSourceManager](wl_registry_bind(
        registry, name,
        addr ext_foreign_toplevel_image_capture_source_manager_v1_interface,
        1))
  of "ext_image_copy_capture_manager_v1":
    list.copyManager = cast[ExtCopyCaptureManager](wl_registry_bind(
        registry, name, addr ext_image_copy_capture_manager_v1_interface, 1))
  else:
    discard

proc registryGlobalRemove(data: pointer, registry: WlRegistry,
    name: uint32) {.cdecl.} =
  discard

var registryListener = WlRegistryListener(global: registryGlobal,
    global_remove: registryGlobalRemove)

proc newWindowList*(display: WlDisplay): WindowList =
  ## Binds the protocols on `display` and waits until the current windows
  ## are known. The list stays alive for the life of the process.
  result = WindowList(display: display)
  GC_ref(result)
  result.registry = wl_display_get_registry(display)
  discard wl_registry_add_listener(result.registry, addr registryListener,
      cast[pointer](result))
  discard wl_display_roundtrip(display) # globals
  discard wl_display_roundtrip(display) # existing toplevels
  discard wl_display_roundtrip(display) # their properties

proc missingProtocols*(list: WindowList): seq[string] =
  ## Protocols the compositor did not offer.
  if list.extList == nil: result.add "ext-foreign-toplevel-list-v1"
  if list.wlrManager == nil: result.add "wlr-foreign-toplevel-management"
  if list.sourceManager == nil:
    result.add "ext-foreign-toplevel-image-capture-source-manager-v1"
  if list.copyManager == nil: result.add "ext-image-copy-capture-v1"
  if list.shm == nil: result.add "wl_shm"
