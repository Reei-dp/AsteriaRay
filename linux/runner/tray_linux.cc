#include "tray_linux.h"

#include <gio/gio.h>
#include <gtk/gtk.h>
#include <libdbusmenu-glib/dbusmenu-glib.h>
#include <libdbusmenu-glib/server.h>
#include <libdbusmenu-gtk/parser.h>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

static GtkWindow* g_tray_window = nullptr;

#define TRAY_NOTIFICATION_WATCHER_ADDR "org.kde.StatusNotifierWatcher"
#define TRAY_NOTIFICATION_WATCHER_OBJ "/StatusNotifierWatcher"
#define TRAY_NOTIFICATION_WATCHER_IFACE "org.kde.StatusNotifierWatcher"
#define TRAY_NOTIFICATION_ITEM_IFACE "org.kde.StatusNotifierItem"
#define TRAY_DEFAULT_ITEM_PATH "/org/ayatana/NotificationItem"

// Ayatana org.kde.StatusNotifierItem XML + ItemIsMenu + Activate + ContextMenu
// (ItemIsMenu=false so LMB calls Activate instead of opening the dbus menu as primary.)
static const char k_tray_sni_introspection_xml[] =
    R"(<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Id" type="s" access="read"/>
    <property name="Category" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="IconAccessibleDesc" type="s" access="read"/>
    <property name="AttentionIconName" type="s" access="read"/>
    <property name="AttentionAccessibleDesc" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="IconThemePath" type="s" access="read"/>
    <property name="Menu" type="o" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <property name="XAyatanaLabel" type="s" access="read"/>
    <property name="XAyatanaLabelGuide" type="s" access="read"/>
    <property name="XAyatanaOrderingIndex" type="u" access="read"/>
    <method name="Activate">
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
    </method>
    <method name="ContextMenu">
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
    </method>
    <method name="Scroll">
      <arg type="i" name="delta" direction="in"/>
      <arg type="s" name="orientation" direction="in"/>
    </method>
    <method name="SecondaryActivate">
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
    </method>
    <method name="XAyatanaSecondaryActivate">
      <arg type="u" name="timestamp" direction="in"/>
    </method>
    <signal name="NewIcon"/>
    <signal name="NewIconThemePath">
      <arg type="s" name="icon_theme_path" direction="out"/>
    </signal>
    <signal name="NewAttentionIcon"/>
    <signal name="NewStatus">
      <arg type="s" name="status" direction="out"/>
    </signal>
    <signal name="XAyatanaNewLabel">
      <arg type="s" name="label" direction="out"/>
      <arg type="s" name="guide" direction="out"/>
    </signal>
    <signal name="NewTitle"/>
  </interface>
</node>)";

typedef struct {
  GtkWindow* window;
  GtkMenu* menu;
  gchar* icon_path_abs;
  gchar* icon_theme_dir;
  gchar* clean_id;
  DbusmenuServer* dbusmenu;
  GDBusConnection* session_bus;
  guint sni_registration_id;
} TraySniCtx;

static TraySniCtx g_sni = {};

extern "C" {

static void tray_restore_main_window(void) {
  if (!g_tray_window) {
    return;
  }
  gtk_window_set_skip_taskbar_hint(g_tray_window, FALSE);
  gtk_widget_show(GTK_WIDGET(g_tray_window));
  gtk_window_deiconify(g_tray_window);
  gtk_window_present(g_tray_window);
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(g_tray_window));
  if (gdk_win != nullptr) {
    gdk_window_raise(gdk_win);
  }
}

static void tray_hide_to_tray(GtkWindow* w) {
  gtk_window_set_skip_taskbar_hint(w, TRUE);
  const gchar* wl = g_getenv("WAYLAND_DISPLAY");
  if (wl != nullptr && wl[0] != '\0') {
    // Match DesktopTrayHolder: hide unmaps the window; iconify leaves a taskbar entry.
    gtk_widget_hide(GTK_WIDGET(w));
  } else {
    gtk_window_move(w, -10000, -10000);
  }
}

static gboolean tray_window_is_collapsed(GtkWindow* w) {
  return gtk_window_get_skip_taskbar_hint(w);
}

static void on_tray_quit(GtkMenuItem* item, gpointer user_data) {
  (void)item;
  GtkWindow* win = GTK_WINDOW(user_data);
  GtkApplication* app = GTK_APPLICATION(gtk_window_get_application(win));
  if (app) {
    g_application_quit(G_APPLICATION(app));
  } else {
    gtk_widget_destroy(GTK_WIDGET(win));
  }
}

#ifdef GDK_WINDOWING_X11
G_GNUC_BEGIN_IGNORE_DEPRECATIONS

static void on_status_icon_activate(GtkStatusIcon* icon, gpointer user_data) {
  (void)icon;
  GtkWindow* w = GTK_WINDOW(user_data);
  if (tray_window_is_collapsed(w)) {
    tray_restore_main_window();
  } else {
    tray_hide_to_tray(w);
  }
}

static void on_status_icon_popup_menu(GtkStatusIcon* status_icon,
                                      guint button,
                                      guint32 activate_time,
                                      gpointer user_data) {
  GtkMenu* menu = GTK_MENU(user_data);
  gtk_menu_popup(menu, nullptr, nullptr, gtk_status_icon_position_menu,
                 status_icon, button, activate_time);
}

G_GNUC_END_IGNORE_DEPRECATIONS
#endif

static gchar* tray_clean_id_from_application_id(void) {
  const char* id = APPLICATION_ID;
  GString* s = g_string_new(nullptr);
  for (const char* p = id; *p != '\0'; p++) {
    g_string_append_c(s,
                        g_ascii_isalnum(static_cast<guchar>(*p)) ? *p : '_');
  }
  return g_string_free(s, FALSE);
}

static gboolean tray_sni_idle_toggle(gpointer user_data) {
  GtkWindow* w = GTK_WINDOW(user_data);
  if (tray_window_is_collapsed(w)) {
    tray_restore_main_window();
  } else {
    tray_hide_to_tray(w);
  }
  g_object_unref(w);
  return G_SOURCE_REMOVE;
}

typedef struct {
  GtkMenu* menu;
  gint x;
  gint y;
} TraySniPopupData;

static gboolean tray_sni_idle_popup(gpointer user_data) {
  auto* d = static_cast<TraySniPopupData*>(user_data);
  GdkRectangle rect = {d->x, d->y, 1, 1};
  GdkWindow* root = gdk_get_default_root_window();
  gtk_menu_popup_at_rect(d->menu, root, &rect, GDK_GRAVITY_NORTH_WEST,
                         GDK_GRAVITY_SOUTH_WEST, nullptr);
  g_free(d);
  return G_SOURCE_REMOVE;
}

static GVariant* tray_sni_get_property(GDBusConnection* /*connection*/,
                                       const gchar* /*sender*/,
                                       const gchar* /*object_path*/,
                                       const gchar* /*interface_name*/,
                                       const gchar* property_name,
                                       GError** error,
                                       gpointer user_data) {
  auto* ctx = static_cast<TraySniCtx*>(user_data);
  if (g_strcmp0(property_name, "Id") == 0) {
    return g_variant_new_string(APPLICATION_ID);
  }
  if (g_strcmp0(property_name, "Category") == 0) {
    return g_variant_new_string("ApplicationStatus");
  }
  if (g_strcmp0(property_name, "Status") == 0) {
    return g_variant_new_string("Active");
  }
  if (g_strcmp0(property_name, "IconName") == 0) {
    return g_variant_new_string(ctx->icon_path_abs ? ctx->icon_path_abs : "");
  }
  if (g_strcmp0(property_name, "IconAccessibleDesc") == 0) {
    return g_variant_new_string("AsteriaRay");
  }
  if (g_strcmp0(property_name, "AttentionIconName") == 0) {
    return g_variant_new_string("");
  }
  if (g_strcmp0(property_name, "AttentionAccessibleDesc") == 0) {
    return g_variant_new_string("");
  }
  if (g_strcmp0(property_name, "Title") == 0) {
    return g_variant_new_string("AsteriaRay");
  }
  if (g_strcmp0(property_name, "IconThemePath") == 0) {
    return g_variant_new_string(ctx->icon_theme_dir ? ctx->icon_theme_dir : "");
  }
  if (g_strcmp0(property_name, "Menu") == 0) {
    if (ctx->dbusmenu != nullptr) {
      GValue strval = {};
      g_value_init(&strval, G_TYPE_STRING);
      g_object_get_property(G_OBJECT(ctx->dbusmenu),
                            DBUSMENU_SERVER_PROP_DBUS_OBJECT, &strval);
      GVariant* var = g_variant_new("o", g_value_get_string(&strval));
      g_value_unset(&strval);
      return var;
    }
    return g_variant_new("o", "/");
  }
  if (g_strcmp0(property_name, "ItemIsMenu") == 0) {
    return g_variant_new_boolean(FALSE);
  }
  if (g_strcmp0(property_name, "XAyatanaLabel") == 0) {
    return g_variant_new_string("");
  }
  if (g_strcmp0(property_name, "XAyatanaLabelGuide") == 0) {
    return g_variant_new_string("");
  }
  if (g_strcmp0(property_name, "XAyatanaOrderingIndex") == 0) {
    return g_variant_new_uint32(0);
  }
  g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED, "Unknown property: %s",
              property_name);
  return nullptr;
}

static void tray_sni_method_call(GDBusConnection* /*connection*/,
                                 const gchar* /*sender*/,
                                 const gchar* /*object_path*/,
                                 const gchar* /*interface_name*/,
                                 const gchar* method_name,
                                 GVariant* parameters,
                                 GDBusMethodInvocation* invocation,
                                 gpointer user_data) {
  auto* ctx = static_cast<TraySniCtx*>(user_data);
  if (g_strcmp0(method_name, "Activate") == 0) {
    g_idle_add(tray_sni_idle_toggle, g_object_ref(ctx->window));
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "ContextMenu") == 0) {
    gint x = 0;
    gint y = 0;
    g_variant_get(parameters, "(ii)", &x, &y);
    auto* pd = g_new0(TraySniPopupData, 1);
    pd->menu = ctx->menu;
    pd->x = x;
    pd->y = y;
    g_idle_add(tray_sni_idle_popup, pd);
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Scroll") == 0 ||
      g_strcmp0(method_name, "SecondaryActivate") == 0 ||
      g_strcmp0(method_name, "XAyatanaSecondaryActivate") == 0) {
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  g_dbus_method_invocation_return_error(invocation, G_IO_ERROR,
                                        G_IO_ERROR_NOT_SUPPORTED,
                                        "Unknown method: %s", method_name);
}

static const GDBusInterfaceVTable k_tray_sni_vtable = {tray_sni_method_call,
                                                        tray_sni_get_property,
                                                        nullptr};

static void tray_init_status_notifier_fallback(GtkWindow* window,
                                               GtkMenu* quit_menu,
                                               const gchar* icon_path) {
  g_autoptr(GError) err = nullptr;

  g_clear_pointer(&g_sni.clean_id, g_free);
  g_clear_pointer(&g_sni.icon_path_abs, g_free);
  g_clear_pointer(&g_sni.icon_theme_dir, g_free);
  g_clear_object(&g_sni.dbusmenu);
  if (g_sni.session_bus != nullptr && g_sni.sni_registration_id != 0) {
    g_dbus_connection_unregister_object(g_sni.session_bus,
                                          g_sni.sni_registration_id);
    g_sni.sni_registration_id = 0;
  }
  g_clear_object(&g_sni.session_bus);

  GDBusConnection* bus =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &err);
  if (!bus) {
    g_warning("tray_linux: session bus: %s", err->message);
    return;
  }
  g_sni.session_bus = bus;

  g_sni.window = window;
  g_sni.menu = quit_menu;
  g_sni.icon_path_abs = g_strdup(icon_path);
  g_sni.icon_theme_dir = g_path_get_dirname(icon_path);
  g_sni.clean_id = tray_clean_id_from_application_id();

  gchar* menu_dbus_path =
      g_strdup_printf(TRAY_DEFAULT_ITEM_PATH "/%s/Menu", g_sni.clean_id);
  g_sni.dbusmenu = dbusmenu_server_new(menu_dbus_path);
  g_free(menu_dbus_path);

  DbusmenuMenuitem* root =
      dbusmenu_gtk_parse_menu_structure(GTK_WIDGET(quit_menu));
  dbusmenu_server_set_root(g_sni.dbusmenu, root);
  if (root != nullptr) {
    g_object_unref(root);
  }

  g_autoptr(GDBusNodeInfo) node_info =
      g_dbus_node_info_new_for_xml(k_tray_sni_introspection_xml, &err);
  if (!node_info) {
    g_warning("tray_linux: SNI introspection: %s", err->message);
    g_clear_object(&g_sni.session_bus);
    return;
  }
  GDBusInterfaceInfo* iface_info = g_dbus_node_info_lookup_interface(
      node_info, TRAY_NOTIFICATION_ITEM_IFACE);
  if (iface_info == nullptr) {
    g_warning("tray_linux: SNI interface missing in XML");
    g_clear_object(&g_sni.session_bus);
    return;
  }

  gchar* sni_path =
      g_strdup_printf(TRAY_DEFAULT_ITEM_PATH "/%s", g_sni.clean_id);
  guint reg_id = g_dbus_connection_register_object(
      bus, sni_path, iface_info, &k_tray_sni_vtable, &g_sni, nullptr, &err);
  if (reg_id == 0) {
    g_warning("tray_linux: register SNI: %s", err->message);
    g_free(sni_path);
    g_clear_object(&g_sni.session_bus);
    return;
  }
  g_sni.sni_registration_id = reg_id;

  g_autoptr(GDBusProxy) watcher = g_dbus_proxy_new_for_bus_sync(
      G_BUS_TYPE_SESSION, G_DBUS_PROXY_FLAGS_NONE, nullptr,
      TRAY_NOTIFICATION_WATCHER_ADDR, TRAY_NOTIFICATION_WATCHER_OBJ,
      TRAY_NOTIFICATION_WATCHER_IFACE, nullptr, &err);
  if (!watcher) {
    g_warning("tray_linux: StatusNotifierWatcher: %s", err->message);
    g_free(sni_path);
    g_clear_object(&g_sni.session_bus);
    return;
  }

  g_dbus_proxy_call_sync(watcher, "RegisterStatusNotifierItem",
                         g_variant_new("(s)", sni_path),
                         G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &err);
  if (err) {
    g_warning("tray_linux: RegisterStatusNotifierItem: %s", err->message);
  }
  g_free(sni_path);
}

}  // extern "C"

void tray_linux_init(GtkWindow* window) {
  g_tray_window = window;

  gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (!exe) {
    g_warning("tray_linux: could not resolve /proc/self/exe");
    return;
  }
  gchar* dir = g_path_get_dirname(exe);
  g_free(exe);
  gchar* icon_path = g_build_filename(dir, "data", "flutter_assets", "assets",
                                      "icon.png", nullptr);
  g_free(dir);

  if (!g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
    g_warning("tray_linux: icon not found: %s", icon_path);
    g_free(icon_path);
    return;
  }

  GtkWidget* quit_menu = gtk_menu_new();
  GtkWidget* item_quit = gtk_menu_item_new_with_label("Выход");
  gtk_menu_shell_append(GTK_MENU_SHELL(quit_menu), item_quit);
  g_signal_connect(item_quit, "activate", G_CALLBACK(on_tray_quit), window);
  gtk_widget_show_all(quit_menu);

#ifdef GDK_WINDOWING_X11
  GdkDisplay* disp = gdk_display_get_default();
  if (disp != nullptr && GDK_IS_X11_DISPLAY(disp)) {
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    GtkStatusIcon* tray_icon = gtk_status_icon_new_from_file(icon_path);
    gtk_status_icon_set_tooltip_text(tray_icon, "AsteriaRay");
    g_signal_connect(tray_icon, "activate", G_CALLBACK(on_status_icon_activate),
                     window);
    g_signal_connect(tray_icon, "popup-menu",
                     G_CALLBACK(on_status_icon_popup_menu), quit_menu);
    gtk_status_icon_set_visible(tray_icon, TRUE);
    g_object_ref_sink(G_OBJECT(tray_icon));
    g_object_ref_sink(G_OBJECT(quit_menu));
    G_GNUC_END_IGNORE_DEPRECATIONS
    g_free(icon_path);
    return;
  }
#endif

  g_object_ref_sink(G_OBJECT(quit_menu));
  tray_init_status_notifier_fallback(window, GTK_MENU(quit_menu), icon_path);
  g_free(icon_path);
}
