#!/usr/bin/env python3
"""Close WPS Office update dialogs that can never receive pointer input.

WPS Office for Linux renders its "new version available" prompt as a frameless
X11 dialog (self-drawn border) marked `_NET_WM_STATE_MODAL`. Under
xwayland-satellite that window ends up below the application's main window in
the X11 stacking order, and the compositor does not route pointer input to it:
every click lands on the modal-blocked main window instead. The dialog can
therefore neither be clicked nor closed with the mouse, and the whole
application stays unusable until it is gone.

Restacking does not help: xwayland-satellite owns the stacking order and
silently ignores client restack requests (`XRaiseWindow`, `XLowerWindow` and
`XConfigureWindow` with `stack_mode=Above` all leave the order unchanged and
report no X11 error). Closing through the standard `WM_DELETE_WINDOW` client
message does work, because that request is handled by WPS itself. This guard
watches the X server and closes such dialogs as soon as they appear.

The dialog is identified by four properties together, so ordinary WPS dialogs
(save as, font settings, ...) are never touched:

  * `WM_CLASS` belongs to a WPS component (et, wps, wpp, wpsoffice, wpspdf)
  * `_NET_WM_WINDOW_TYPE` contains DIALOG
  * `_NET_WM_STATE` contains MODAL
  * `_MOTIF_WM_HINTS` disables decorations, i.e. the window draws its own
    border instead of getting one from the window manager

See `MAINTENANCE.md` for the analysis, the upstream situation and the removal
conditions of this workaround.
"""

import os
import time

# The unit runs from the graphical session, where DISPLAY is normally exported,
# but a missing value would otherwise raise before the retry loop can start.
os.environ.setdefault("DISPLAY", ":0")

from Xlib import X, display, protocol  # noqa: E402
from Xlib.error import XError  # noqa: E402

WPS_CLASSES = frozenset({"et", "wps", "wpp", "wpsoffice", "wpspdf"})
POLL_SECONDS = 0.5
RETRY_SECONDS = 5


def log(message):
    print(message, flush=True)


def property_value(dpy, win, name):
    """Raw value of a window property, or None when it is absent."""
    try:
        prop = win.get_full_property(dpy.intern_atom(name), X.AnyPropertyType)
    except XError:
        return None
    if prop is None:
        return None
    return prop.value


def property_has_atom(dpy, win, name, needle):
    """Whether an ATOM list property contains a name with the given substring."""
    value = property_value(dpy, win, name)
    if value is None:
        return False
    for item in value:
        try:
            if needle in dpy.get_atom_name(item):
                return True
        except XError:
            continue
    return False


def motif_is_frameless(dpy, win):
    """True when `_MOTIF_WM_HINTS` explicitly turns decorations off."""
    hints = property_value(dpy, win, "_MOTIF_WM_HINTS")
    if hints is None or len(hints) < 3:
        return False
    # MotifWmHints: flags, functions, decorations, input_mode, status
    flags = int(hints[0])
    decorations = int(hints[2])
    return bool(flags & 2) and decorations == 0


def update_dialog_title(dpy, win):
    """Return the dialog title when the window is a WPS update prompt."""
    try:
        attributes = win.get_attributes()
        if attributes.map_state != X.IsViewable or attributes.override_redirect:
            return None
        wm_class = win.get_wm_class()
        if not wm_class or wm_class[0] not in WPS_CLASSES:
            return None
        if not property_has_atom(dpy, win, "_NET_WM_WINDOW_TYPE", "DIALOG"):
            return None
        if not property_has_atom(dpy, win, "_NET_WM_STATE", "MODAL"):
            return None
        if not motif_is_frameless(dpy, win):
            return None
        title = win.get_wm_name()
        return title or "<untitled>"
    except (XError, OSError, ValueError):
        # Windows disappear while we walk the tree; that is not an error.
        return None


def send_close(dpy, win):
    """Ask the owning application to close the window, as clicking X would."""
    event = protocol.event.ClientMessage(
        window=win,
        client_type=dpy.intern_atom("WM_PROTOCOLS"),
        data=(32, [dpy.intern_atom("WM_DELETE_WINDOW"), X.CurrentTime, 0, 0, 0]),
    )
    win.send_event(event, event_mask=0, propagate=False)
    dpy.flush()


def guard_once(dpy):
    for win in dpy.screen().root.query_tree().children:
        title = update_dialog_title(dpy, win)
        if title is None:
            continue
        log(f"closing WPS update dialog {title!r}")
        send_close(dpy, win)


def main():
    while True:
        try:
            dpy = display.Display()
            log(f"watching {dpy.get_display_name()} for WPS update dialogs")
            while True:
                guard_once(dpy)
                dpy.flush()
                time.sleep(POLL_SECONDS)
        except Exception as exc:  # noqa: BLE001 - keep the guard alive forever
            # Xwayland or the session may not be up yet, and it may restart.
            log(f"X connection problem ({exc!r}); retrying in {RETRY_SECONDS}s")
            time.sleep(RETRY_SECONDS)


if __name__ == "__main__":
    main()
