#ifndef OPENJARVIS_BRIDGE_H
#define OPENJARVIS_BRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
char *oj_window_json(const char *input);
void oj_string_free(char *value);
int32_t oj_authorize_action_json(const char *input);
#ifdef __cplusplus
}
#endif
#endif
