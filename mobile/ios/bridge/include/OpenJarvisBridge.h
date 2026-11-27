#ifndef OPENJARVIS_BRIDGE_H
#define OPENJARVIS_BRIDGE_H
#ifdef __cplusplus
extern "C" {
#endif
char *oj_window_json(const char *input);
void oj_string_free(char *value);
#ifdef __cplusplus
}
#endif
#endif
