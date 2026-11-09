"""Native app chooser; requires Python 3, PyGObject and GTK 3."""
import sys

try:
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gio, Gtk

    ready, _ = Gtk.init_check()
    if not ready:
        raise RuntimeError("No graphical desktop (DISPLAY/Wayland session)")
    target = Gio.File.new_for_path(sys.argv[1])
    dialog = Gtk.AppChooserDialog.new(None, Gtk.DialogFlags.MODAL, target)
    dialog.set_heading("Open file with")
    try:
        if dialog.run() == Gtk.ResponseType.OK:
            app = dialog.get_app_info()
            if app is None:
                raise RuntimeError("No application selected")
            app.launch([target], None)
    finally:
        dialog.destroy()
except Exception as error:
    print(f"pathclick: {error}. App choice needs Python 3 + PyGObject + GTK 3 "
          "(Debian/Ubuntu: sudo apt install python3-gi gir1.2-gtk-3.0).", file=sys.stderr)
    sys.exit(1)
