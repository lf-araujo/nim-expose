## Hand-written bindings for libwayland-client and the protocols in
## `protocols/`: ext-foreign-toplevel-list, ext-image-capture-source,
## ext-image-copy-capture and wlr-foreign-toplevel-management.
##
## Request functions are the `static inline` wrappers that wayland-scanner
## generates (C names kept); listener structs mirror the generated ones
## field for field. Regenerate the C glue with `tools/gen-protocols.sh`.

import std/os

const protoDir = currentSourcePath().parentDir() / "proto"

{.passC: "-I" & protoDir.}
{.passL: "-lwayland-client".}
# Listener callbacks take `cstring` (char *) where the generated structs say
# `const char *`; the ABI is the same, so silence GCC 14's error for that.
{.passC: "-Wno-incompatible-pointer-types".}
{.compile: protoDir / "ext-foreign-toplevel-list-v1-protocol.c".}
{.compile: protoDir / "ext-image-capture-source-v1-protocol.c".}
{.compile: protoDir / "ext-image-copy-capture-v1-protocol.c".}
{.compile: protoDir / "wlr-foreign-toplevel-management-unstable-v1-protocol.c".}

const
  coreHeader = "<wayland-client.h>"
  listHeader = "ext-foreign-toplevel-list-v1-client-protocol.h"
  sourceHeader = "ext-image-capture-source-v1-client-protocol.h"
  copyHeader = "ext-image-copy-capture-v1-client-protocol.h"
  wlrHeader = "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

type
  # Opaque protocol objects, declared as the C structs so the generated
  # inline functions type-check.
  WlDisplayObj {.importc: "struct wl_display",
      header: coreHeader, incompleteStruct.} = object
  WlDisplay* = ptr WlDisplayObj
  WlRegistryObj {.importc: "struct wl_registry",
      header: coreHeader, incompleteStruct.} = object
  WlRegistry* = ptr WlRegistryObj
  WlSeatObj {.importc: "struct wl_seat",
      header: coreHeader, incompleteStruct.} = object
  WlSeat* = ptr WlSeatObj
  WlOutputObj {.importc: "struct wl_output",
      header: coreHeader, incompleteStruct.} = object
  WlOutput* = ptr WlOutputObj
  WlShmObj {.importc: "struct wl_shm",
      header: coreHeader, incompleteStruct.} = object
  WlShm* = ptr WlShmObj
  WlShmPoolObj {.importc: "struct wl_shm_pool",
      header: coreHeader, incompleteStruct.} = object
  WlShmPool* = ptr WlShmPoolObj
  WlBufferObj {.importc: "struct wl_buffer",
      header: coreHeader, incompleteStruct.} = object
  WlBuffer* = ptr WlBufferObj
  ExtToplevelListObj {.importc: "struct ext_foreign_toplevel_list_v1",
      header: listHeader, incompleteStruct.} = object
  ExtToplevelList* = ptr ExtToplevelListObj
  ExtToplevelObj {.importc: "struct ext_foreign_toplevel_handle_v1",
      header: listHeader, incompleteStruct.} = object
  ExtToplevel* = ptr ExtToplevelObj
  ExtCaptureSourceObj {.importc: "struct ext_image_capture_source_v1",
      header: sourceHeader, incompleteStruct.} = object
  ExtCaptureSource* = ptr ExtCaptureSourceObj
  ExtToplevelSourceManagerObj {.importc: "struct ext_foreign_toplevel_image_capture_source_manager_v1",
      header: sourceHeader, incompleteStruct.} = object
  ExtToplevelSourceManager* = ptr ExtToplevelSourceManagerObj
  ExtCopyCaptureManagerObj {.importc: "struct ext_image_copy_capture_manager_v1",
      header: copyHeader, incompleteStruct.} = object
  ExtCopyCaptureManager* = ptr ExtCopyCaptureManagerObj
  ExtCopyCaptureSessionObj {.importc: "struct ext_image_copy_capture_session_v1",
      header: copyHeader, incompleteStruct.} = object
  ExtCopyCaptureSession* = ptr ExtCopyCaptureSessionObj
  ExtCopyCaptureFrameObj {.importc: "struct ext_image_copy_capture_frame_v1",
      header: copyHeader, incompleteStruct.} = object
  ExtCopyCaptureFrame* = ptr ExtCopyCaptureFrameObj
  WlrToplevelManagerObj {.importc: "struct zwlr_foreign_toplevel_manager_v1",
      header: wlrHeader, incompleteStruct.} = object
  WlrToplevelManager* = ptr WlrToplevelManagerObj
  WlrToplevelObj {.importc: "struct zwlr_foreign_toplevel_handle_v1",
      header: wlrHeader, incompleteStruct.} = object
  WlrToplevel* = ptr WlrToplevelObj
  WlInterface* {.importc: "struct wl_interface", header: coreHeader,
      incompleteStruct.} = object
  WlArray* {.importc: "struct wl_array", header: coreHeader, bycopy.} = object
    size*, alloc*: csize_t
    data*: pointer

  WlRegistryListener* {.importc: "struct wl_registry_listener",
      header: coreHeader.} = object
    global*: proc (data: pointer, registry: WlRegistry, name: uint32,
        iface: cstring, version: uint32) {.cdecl.}
    global_remove*: proc (data: pointer, registry: WlRegistry,
        name: uint32) {.cdecl.}

  ExtToplevelListListener* {.importc:
      "struct ext_foreign_toplevel_list_v1_listener", header: listHeader.} =
      object
    toplevel*: proc (data: pointer, list: ExtToplevelList,
        toplevel: ExtToplevel) {.cdecl.}
    finished*: proc (data: pointer, list: ExtToplevelList) {.cdecl.}

  ExtToplevelListener* {.importc:
      "struct ext_foreign_toplevel_handle_v1_listener", header: listHeader.} =
      object
    closed*: proc (data: pointer, toplevel: ExtToplevel) {.cdecl.}
    done*: proc (data: pointer, toplevel: ExtToplevel) {.cdecl.}
    title*: proc (data: pointer, toplevel: ExtToplevel,
        title: cstring) {.cdecl.}
    app_id*: proc (data: pointer, toplevel: ExtToplevel,
        appId: cstring) {.cdecl.}
    identifier*: proc (data: pointer, toplevel: ExtToplevel,
        identifier: cstring) {.cdecl.}

  ExtSessionListener* {.importc:
      "struct ext_image_copy_capture_session_v1_listener",
      header: copyHeader.} = object
    buffer_size*: proc (data: pointer, session: ExtCopyCaptureSession,
        width, height: uint32) {.cdecl.}
    shm_format*: proc (data: pointer, session: ExtCopyCaptureSession,
        format: uint32) {.cdecl.}
    dmabuf_device*: proc (data: pointer, session: ExtCopyCaptureSession,
        device: ptr WlArray) {.cdecl.}
    dmabuf_format*: proc (data: pointer, session: ExtCopyCaptureSession,
        format: uint32, modifiers: ptr WlArray) {.cdecl.}
    done*: proc (data: pointer, session: ExtCopyCaptureSession) {.cdecl.}
    stopped*: proc (data: pointer, session: ExtCopyCaptureSession) {.cdecl.}

  ExtFrameListener* {.importc:
      "struct ext_image_copy_capture_frame_v1_listener",
      header: copyHeader.} = object
    transform*: proc (data: pointer, frame: ExtCopyCaptureFrame,
        transform: uint32) {.cdecl.}
    damage*: proc (data: pointer, frame: ExtCopyCaptureFrame,
        x, y, width, height: int32) {.cdecl.}
    presentation_time*: proc (data: pointer, frame: ExtCopyCaptureFrame,
        secHi, secLo, nsec: uint32) {.cdecl.}
    ready*: proc (data: pointer, frame: ExtCopyCaptureFrame) {.cdecl.}
    failed*: proc (data: pointer, frame: ExtCopyCaptureFrame,
        reason: uint32) {.cdecl.}

  WlrToplevelManagerListener* {.importc:
      "struct zwlr_foreign_toplevel_manager_v1_listener",
      header: wlrHeader.} = object
    toplevel*: proc (data: pointer, manager: WlrToplevelManager,
        toplevel: WlrToplevel) {.cdecl.}
    finished*: proc (data: pointer, manager: WlrToplevelManager) {.cdecl.}

  WlrToplevelListener* {.importc:
      "struct zwlr_foreign_toplevel_handle_v1_listener",
      header: wlrHeader.} = object
    title*: proc (data: pointer, toplevel: WlrToplevel,
        title: cstring) {.cdecl.}
    app_id*: proc (data: pointer, toplevel: WlrToplevel,
        appId: cstring) {.cdecl.}
    output_enter*: proc (data: pointer, toplevel: WlrToplevel,
        output: WlOutput) {.cdecl.}
    output_leave*: proc (data: pointer, toplevel: WlrToplevel,
        output: WlOutput) {.cdecl.}
    state*: proc (data: pointer, toplevel: WlrToplevel,
        state: ptr WlArray) {.cdecl.}
    done*: proc (data: pointer, toplevel: WlrToplevel) {.cdecl.}
    closed*: proc (data: pointer, toplevel: WlrToplevel) {.cdecl.}
    parent*: proc (data: pointer, toplevel: WlrToplevel,
        parent: WlrToplevel) {.cdecl.}

const
  WL_SHM_FORMAT_ARGB8888* = 0'u32
  WL_SHM_FORMAT_XRGB8888* = 1'u32
  # The same two formats as DRM fourcc codes, which some compositors send
  # in ext-image-copy-capture's shm_format event instead.
  DRM_FORMAT_ARGB8888* = 0x34325241'u32 # "AR24"
  DRM_FORMAT_XRGB8888* = 0x34325258'u32 # "XR24"
  # Red and blue swapped; wl_shm uses the same codes for these. labwc
  # offers XBGR8888 for window capture.
  DRM_FORMAT_ABGR8888* = 0x34324241'u32 # "AB24"
  DRM_FORMAT_XBGR8888* = 0x34324258'u32 # "XB24"
  WLR_STATE_MAXIMIZED* = 0'u32
  WLR_STATE_MINIMIZED* = 1'u32
  WLR_STATE_ACTIVATED* = 2'u32
  WLR_STATE_FULLSCREEN* = 3'u32

var
  wl_seat_interface* {.importc, header: coreHeader.}: WlInterface
  wl_shm_interface* {.importc, header: coreHeader.}: WlInterface
  ext_foreign_toplevel_list_v1_interface* {.importc, header: listHeader.}:
    WlInterface
  ext_foreign_toplevel_image_capture_source_manager_v1_interface*
    {.importc, header: sourceHeader.}: WlInterface
  ext_image_copy_capture_manager_v1_interface* {.importc,
    header: copyHeader.}: WlInterface
  zwlr_foreign_toplevel_manager_v1_interface* {.importc,
    header: wlrHeader.}: WlInterface

{.push importc, cdecl, header: coreHeader.}
proc wl_display_connect*(name: cstring): WlDisplay
proc wl_display_disconnect*(display: WlDisplay)
proc wl_display_roundtrip*(display: WlDisplay): cint
proc wl_display_flush*(display: WlDisplay): cint
proc wl_display_dispatch*(display: WlDisplay): cint
{.pop.}

{.push importc, cdecl, header: coreHeader.}
proc wl_display_get_registry*(display: WlDisplay): WlRegistry
proc wl_registry_add_listener*(registry: WlRegistry,
    listener: ptr WlRegistryListener, data: pointer): cint
proc wl_registry_bind*(registry: WlRegistry, name: uint32,
    iface: ptr WlInterface, version: uint32): pointer
proc wl_shm_create_pool*(shm: WlShm, fd: cint, size: int32): WlShmPool
proc wl_shm_pool_create_buffer*(pool: WlShmPool, offset, width, height,
    stride: int32, format: uint32): WlBuffer
proc wl_shm_pool_destroy*(pool: WlShmPool)
proc wl_buffer_destroy*(buffer: WlBuffer)
{.pop.}

{.push importc, cdecl, header: listHeader.}
proc ext_foreign_toplevel_list_v1_add_listener*(list: ExtToplevelList,
    listener: ptr ExtToplevelListListener, data: pointer): cint
proc ext_foreign_toplevel_list_v1_stop*(list: ExtToplevelList)
proc ext_foreign_toplevel_handle_v1_add_listener*(toplevel: ExtToplevel,
    listener: ptr ExtToplevelListener, data: pointer): cint
proc ext_foreign_toplevel_handle_v1_destroy*(toplevel: ExtToplevel)
{.pop.}

{.push importc, cdecl, header: sourceHeader.}
proc ext_foreign_toplevel_image_capture_source_manager_v1_create_source*(
    manager: ExtToplevelSourceManager, toplevel: ExtToplevel):
    ExtCaptureSource
proc ext_image_capture_source_v1_destroy*(source: ExtCaptureSource)
{.pop.}

{.push importc, cdecl, header: copyHeader.}
proc ext_image_copy_capture_manager_v1_create_session*(
    manager: ExtCopyCaptureManager, source: ExtCaptureSource,
    options: uint32): ExtCopyCaptureSession
proc ext_image_copy_capture_session_v1_add_listener*(
    session: ExtCopyCaptureSession, listener: ptr ExtSessionListener,
    data: pointer): cint
proc ext_image_copy_capture_session_v1_create_frame*(
    session: ExtCopyCaptureSession): ExtCopyCaptureFrame
proc ext_image_copy_capture_session_v1_destroy*(
    session: ExtCopyCaptureSession)
proc ext_image_copy_capture_frame_v1_add_listener*(
    frame: ExtCopyCaptureFrame, listener: ptr ExtFrameListener,
    data: pointer): cint
proc ext_image_copy_capture_frame_v1_attach_buffer*(
    frame: ExtCopyCaptureFrame, buffer: WlBuffer)
proc ext_image_copy_capture_frame_v1_damage_buffer*(
    frame: ExtCopyCaptureFrame, x, y, width, height: int32)
proc ext_image_copy_capture_frame_v1_capture*(frame: ExtCopyCaptureFrame)
proc ext_image_copy_capture_frame_v1_destroy*(frame: ExtCopyCaptureFrame)
{.pop.}

{.push importc, cdecl, header: wlrHeader.}
proc zwlr_foreign_toplevel_manager_v1_add_listener*(
    manager: WlrToplevelManager, listener: ptr WlrToplevelManagerListener,
    data: pointer): cint
proc zwlr_foreign_toplevel_handle_v1_add_listener*(toplevel: WlrToplevel,
    listener: ptr WlrToplevelListener, data: pointer): cint
proc zwlr_foreign_toplevel_handle_v1_activate*(toplevel: WlrToplevel,
    seat: WlSeat)
proc zwlr_foreign_toplevel_handle_v1_close*(toplevel: WlrToplevel)
proc zwlr_foreign_toplevel_handle_v1_destroy*(toplevel: WlrToplevel)
{.pop.}

iterator uint32Items*(arr: ptr WlArray): uint32 =
  ## The elements of a `wl_array` of `uint32` (e.g. toplevel states).
  let items = cast[ptr UncheckedArray[uint32]](arr.data)
  for i in 0 ..< int(arr.size div 4):
    yield items[i]
