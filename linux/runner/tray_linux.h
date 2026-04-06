#ifndef RUNNER_TRAY_LINUX_H_
#define RUNNER_TRAY_LINUX_H_

#include <gtk/gtk.h>

#ifdef __cplusplus
extern "C" {
#endif

void tray_linux_init(GtkWindow* window);

#ifdef __cplusplus
}
#endif

#endif  // RUNNER_TRAY_LINUX_H_
