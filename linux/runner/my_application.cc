#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <unistd.h>

#include "flutter/generated_plugin_registrant.h"
#include "tray_linux.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void set_window_icon_from_png(GtkWindow* window) {
  gchar exe_path[4096] = {0};
  const ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
  if (len <= 0) {
    return;
  }
  exe_path[len] = '\0';

  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  g_autofree gchar* icon_in_bundle =
      g_build_filename(exe_dir, "icons", APPLICATION_ID ".png", nullptr);

  const gchar* icon_path = nullptr;
  if (g_file_test(icon_in_bundle, G_FILE_TEST_EXISTS)) {
    icon_path = icon_in_bundle;
  } else {
    g_autofree gchar* cwd = g_get_current_dir();
    g_autofree gchar* icon_in_project =
        g_build_filename(cwd, "assets", "dekstop_icon.png", nullptr);
    if (g_file_test(icon_in_project, G_FILE_TEST_EXISTS)) {
      // Fallback for local `flutter run -d linux` from source tree.
      icon_path = icon_in_project;
    }
  }

  if (icon_path != nullptr) {
    g_autoptr(GError) error = nullptr;
    gtk_window_set_default_icon_from_file(icon_path, &error);
    if (error != nullptr) {
      g_warning("Failed to set PNG app icon: %s", error->message);
    }

    // Explicitly set icon for this concrete window as well (taskbar/dock).
    g_clear_error(&error);
    gtk_window_set_icon_from_file(window, icon_path, &error);
    if (error != nullptr) {
      g_warning("Failed to set window PNG icon: %s", error->message);
    }
  }

  // Some DE/taskbars prefer icon name lookup over pixbuf; keep it aligned with
  // the application ID/desktop entry.
  gtk_window_set_icon_name(window, APPLICATION_ID);
}

static void apply_headerbar_css() {
  static const gchar* kHeaderbarCss = R"(
window#asteria-window,
window#asteria-window.background {
  border-radius: 0 0 16px 16px;
  background-color: #000000;
}

headerbar.titlebar {
  background: #171c22;
  background-image: none;
  border: none;
  border-bottom: 1px solid #2a313c;
  min-height: 42px;
  padding: 0 6px;
}

headerbar.titlebar .title {
  color: #f2f5f8;
  font-weight: 600;
  letter-spacing: 0.2px;
}

headerbar.titlebar button.titlebutton {
  min-width: 28px;
  min-height: 28px;
  border-radius: 8px;
  margin: 0 2px;
  padding: 0;
}

headerbar.titlebar button.titlebutton:hover {
  background-color: rgba(255, 255, 255, 0.08);
}
)";

  GtkCssProvider* provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(provider, kHeaderbarCss, -1, nullptr);
  GdkScreen* screen = gdk_screen_get_default();
  if (screen != nullptr) {
    gtk_style_context_add_provider_for_screen(
        screen, GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }
  g_object_unref(provider);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  set_window_icon_from_png(window);
  gtk_widget_set_name(GTK_WIDGET(window), "asteria-window");

  // Allow RGBA compositing so GTK-side rounded corners can be rendered cleanly.
  GdkScreen* rgba_screen = gtk_widget_get_screen(GTK_WIDGET(window));
  if (rgba_screen != nullptr) {
    GdkVisual* rgba_visual = gdk_screen_get_rgba_visual(rgba_screen);
    if (rgba_visual != nullptr) {
      gtk_widget_set_visual(GTK_WIDGET(window), rgba_visual);
      gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
    }
  }

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    apply_headerbar_css();
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_style_context_add_class(gtk_widget_get_style_context(GTK_WIDGET(header_bar)),
                                "titlebar");
    gtk_header_bar_set_title(header_bar, "Asteria");
    gtk_header_bar_set_subtitle(header_bar, nullptr);
    gtk_header_bar_set_decoration_layout(header_bar, ":minimize,maximize,close");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Asteria");
  }

  const gint kWindowWidth = 550;
  const gint kDefaultHeight = 800;
  gtk_window_set_default_size(window, kWindowWidth, kDefaultHeight);
  // Fixed width (narrow phone-style layout); height stays resizable.
  GdkGeometry geometry;
  geometry.min_width = kWindowWidth;
  geometry.max_width = kWindowWidth;
  geometry.min_height = 480;
  geometry.max_height = 10000;
  gtk_window_set_geometry_hints(
      window, nullptr, &geometry,
      static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Keep Flutter surface opaque; rounded corners are handled on GTK side.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  tray_linux_init(window);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
