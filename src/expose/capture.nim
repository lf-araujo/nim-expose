## Captures one frame of a window's contents through ext-image-copy-capture,
## into a shared-memory buffer, and keeps a downscaled copy as a cairo
## surface (`Window.thumbnail`).
##
## Each capture is asynchronous: `capture` returns at once and the window's
## `onCaptured` callback runs from the Wayland event loop when the frame is
## ready (or failed).

import std/posix
import ./[cairo, wayland, windows]

type
  Capture = ref object
    list: WindowList
    window: Window
    source: ExtCaptureSource
    session: ExtCopyCaptureSession
    frame: ExtCopyCaptureFrame
    width, height: int
    formats: seq[uint32]
    fd: cint
    data: pointer
    size: int
    pool: WlShmPool
    buffer: WlBuffer
    maxWidth: int
    done: proc (data: pointer, window: Window, ok: bool) {.nimcall.}
    doneData: pointer

proc memfd_create(name: cstring, flags: cuint): cint {.importc,
    header: "<sys/mman.h>".}

proc finish(capture: Capture, ok: bool) =
  if capture.frame != nil:
    ext_image_copy_capture_frame_v1_destroy(capture.frame)
  if capture.session != nil:
    ext_image_copy_capture_session_v1_destroy(capture.session)
  if capture.source != nil:
    ext_image_capture_source_v1_destroy(capture.source)
  if capture.buffer != nil:
    wl_buffer_destroy(capture.buffer)
  if capture.pool != nil:
    wl_shm_pool_destroy(capture.pool)
  if capture.data != nil:
    discard munmap(capture.data, capture.size)
  if capture.fd >= 0:
    discard close(capture.fd)
  discard wl_display_flush(capture.list.display)
  if capture.done != nil:
    capture.done(capture.doneData, capture.window, ok)
  GC_unref(capture)

type Box = tuple[x, y, width, height: int]

proc contentBox(data: pointer, width, height: int): Box =
  ## The smallest box holding every pixel that is not pure black. Windows
  ## with client-side shadows are captured without alpha, so the shadow
  ## margin arrives as a black frame; this crops it off.
  let pixels = cast[ptr UncheckedArray[uint32]](data)
  template blank(px: uint32): bool = (px and 0x00FFFFFF'u32) == 0
  proc rowBlank(y: int): bool =
    result = true
    for x in 0 ..< width:
      if not blank(pixels[y * width + x]):
        return false
  proc columnBlank(x, top, bottom: int): bool =
    result = true
    for y in top .. bottom:
      if not blank(pixels[y * width + x]):
        return false
  var
    top = 0
    bottom = height - 1
  while top < bottom and rowBlank(top):
    inc top
  while bottom > top and rowBlank(bottom):
    dec bottom
  var
    left = 0
    right = width - 1
  while left < right and columnBlank(left, top, bottom):
    inc left
  while right > left and columnBlank(right, top, bottom):
    dec right
  (left, top, right - left + 1, bottom - top + 1)

proc keepThumbnail(capture: Capture, format: cint) =
  ## Copies the captured pixels, minus any black shadow margin, into a
  ## surface no wider than `maxWidth`.
  let
    stride = cint(capture.width * 4)
    raw = cairo_image_surface_create_for_data(capture.data, format,
        cint(capture.width), cint(capture.height), stride)
    box =
      if format == CAIRO_FORMAT_RGB24:
        contentBox(capture.data, capture.width, capture.height)
      else:
        (0, 0, capture.width, capture.height)
    scale = min(1.0, capture.maxWidth / box.width)
    width = max(1, int(box.width.float * scale))
    height = max(1, int(box.height.float * scale))
    thumb = cairo_image_surface_create(format, cint(width), cint(height))
    cr = cairo_create(thumb)
  cairo_scale(cr, scale, scale)
  cairo_set_source_surface(cr, raw, -box.x.float, -box.y.float)
  cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_GOOD)
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
  cairo_paint(cr)
  cairo_destroy(cr)
  cairo_surface_destroy(raw)
  if capture.window.thumbnail != nil:
    cairo_surface_destroy(cast[CairoSurface](capture.window.thumbnail))
  capture.window.thumbnail = thumb

# --- Frame ----------------------------------------------------------------

proc frameTransform(data: pointer, frame: ExtCopyCaptureFrame,
    transform: uint32) {.cdecl.} =
  discard

proc frameDamage(data: pointer, frame: ExtCopyCaptureFrame,
    x, y, width, height: int32) {.cdecl.} =
  discard

proc framePresentationTime(data: pointer, frame: ExtCopyCaptureFrame,
    secHi, secLo, nsec: uint32) {.cdecl.} =
  discard

func hasAlpha(format: uint32): bool =
  format in [WL_SHM_FORMAT_ARGB8888, DRM_FORMAT_ARGB8888, DRM_FORMAT_ABGR8888]

func isBgr(format: uint32): bool =
  ## Red in the low byte, i.e. the reverse of cairo's layout.
  format in [DRM_FORMAT_ABGR8888, DRM_FORMAT_XBGR8888]

func isSupported(format: uint32): bool =
  format in [WL_SHM_FORMAT_ARGB8888, WL_SHM_FORMAT_XRGB8888,
    DRM_FORMAT_ARGB8888, DRM_FORMAT_XRGB8888, DRM_FORMAT_ABGR8888,
    DRM_FORMAT_XBGR8888]

proc swapRedBlue(data: pointer, size: int) =
  let bytes = cast[ptr UncheckedArray[uint8]](data)
  var i = 0
  while i + 3 < size:
    swap(bytes[i], bytes[i + 2])
    i += 4

proc chosenFormat(capture: Capture): uint32 =
  ## A 32-bit (A|X)RGB format the compositor offered, preferring alpha;
  ## its value is passed back exactly as advertised.
  result = 0xFFFFFFFF'u32
  for format in capture.formats:
    if format.isSupported and (result == 0xFFFFFFFF'u32 or format.hasAlpha):
      result = format

proc frameReady(data: pointer, frame: ExtCopyCaptureFrame) {.cdecl.} =
  let capture = cast[Capture](data)
  if capture.chosenFormat.isBgr:
    swapRedBlue(capture.data, capture.size)
  capture.keepThumbnail(
      if capture.chosenFormat.hasAlpha: CAIRO_FORMAT_ARGB32
      else: CAIRO_FORMAT_RGB24)
  capture.finish(true)

proc frameFailed(data: pointer, frame: ExtCopyCaptureFrame, reason: uint32)
    {.cdecl.} =
  when defined(exposeDebug):
    stderr.writeLine "frame failed, reason ", reason
  cast[Capture](data).finish(false)

var frameListener = ExtFrameListener(transform: frameTransform,
    damage: frameDamage, presentation_time: framePresentationTime,
    ready: frameReady, failed: frameFailed)

# --- Session --------------------------------------------------------------

proc sessionBufferSize(data: pointer, session: ExtCopyCaptureSession,
    width, height: uint32) {.cdecl.} =
  let capture = cast[Capture](data)
  capture.width = int(width)
  capture.height = int(height)

proc sessionShmFormat(data: pointer, session: ExtCopyCaptureSession,
    format: uint32) {.cdecl.} =
  cast[Capture](data).formats.add format

proc sessionDmabufDevice(data: pointer, session: ExtCopyCaptureSession,
    device: ptr WlArray) {.cdecl.} =
  discard

proc sessionDmabufFormat(data: pointer, session: ExtCopyCaptureSession,
    format: uint32, modifiers: ptr WlArray) {.cdecl.} =
  discard

proc allocateBuffer(capture: Capture): bool =
  let stride = capture.width * 4
  capture.size = stride * capture.height
  capture.fd = memfd_create("nim-expose-capture", 0)
  if capture.fd < 0 or ftruncate(capture.fd, Off(capture.size)) != 0:
    return false
  capture.data = mmap(nil, capture.size, PROT_READ or PROT_WRITE,
      MAP_SHARED, capture.fd, 0)
  if capture.data == MAP_FAILED:
    capture.data = nil
    return false
  capture.pool = wl_shm_create_pool(capture.list.shm, capture.fd,
      int32(capture.size))
  capture.buffer = wl_shm_pool_create_buffer(capture.pool, 0,
      int32(capture.width), int32(capture.height), int32(stride),
      capture.chosenFormat)
  true

proc sessionDone(data: pointer, session: ExtCopyCaptureSession) {.cdecl.} =
  ## The buffer constraints are known: allocate a buffer and request a
  ## frame (only the first time; a later `done` means the window resized).
  let capture = cast[Capture](data)
  if capture.frame != nil:
    return
  let usable = capture.width > 0 and capture.height > 0 and
      capture.chosenFormat != 0xFFFFFFFF'u32
  when defined(exposeDebug):
    stderr.writeLine "session done: ", capture.width, "x", capture.height,
      " formats ", capture.formats
  if not usable or not capture.allocateBuffer():
    capture.finish(false)
  else:
    capture.frame = ext_image_copy_capture_session_v1_create_frame(session)
    discard ext_image_copy_capture_frame_v1_add_listener(capture.frame,
        addr frameListener, data)
    ext_image_copy_capture_frame_v1_attach_buffer(capture.frame,
        capture.buffer)
    ext_image_copy_capture_frame_v1_damage_buffer(capture.frame, 0, 0,
        int32(capture.width), int32(capture.height))
    ext_image_copy_capture_frame_v1_capture(capture.frame)
    discard wl_display_flush(capture.list.display)

proc sessionStopped(data: pointer, session: ExtCopyCaptureSession)
    {.cdecl.} =
  let capture = cast[Capture](data)
  when defined(exposeDebug):
    stderr.writeLine "session stopped"
  if capture.frame == nil:
    capture.finish(false)

var sessionListener = ExtSessionListener(buffer_size: sessionBufferSize,
    shm_format: sessionShmFormat, dmabuf_device: sessionDmabufDevice,
    dmabuf_format: sessionDmabufFormat, done: sessionDone,
    stopped: sessionStopped)

proc capture*(list: WindowList, window: Window, maxWidth: int,
    done: proc (data: pointer, window: Window, ok: bool) {.nimcall.},
    doneData: pointer = nil) =
  ## Starts capturing `window`; on success `window.thumbnail` holds a cairo
  ## surface at most `maxWidth` pixels wide. `done` is called either way.
  let capture = Capture(list: list, window: window, fd: -1,
      maxWidth: maxWidth, done: done, doneData: doneData)
  GC_ref(capture)
  capture.source =
    ext_foreign_toplevel_image_capture_source_manager_v1_create_source(
      list.sourceManager, window.ext)
  capture.session = ext_image_copy_capture_manager_v1_create_session(
      list.copyManager, capture.source, 0)
  discard ext_image_copy_capture_session_v1_add_listener(capture.session,
      addr sessionListener, cast[pointer](capture))
  discard wl_display_flush(list.display)
