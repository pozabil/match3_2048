#include <emscripten.h>

// Save UTF-8 JSON string to localStorage.
EMSCRIPTEN_KEEPALIVE
void web_storage_save(const char* data, int len) {
    EM_ASM({
        var str = UTF8ToString($0, $1);
        localStorage.setItem('match3_2048_save', str);
    }, data, len);
}

// Load JSON string from localStorage into buf.
// Returns byte count written, or -1 if key not found, or -2 if buf too small.
EMSCRIPTEN_KEEPALIVE
int web_storage_load(char* buf, int buf_len) {
    return EM_ASM_INT({
        var str = localStorage.getItem('match3_2048_save');
        if (str === null) return -1;
        var len = lengthBytesUTF8(str);
        if (len >= $1) return -2;
        stringToUTF8(str, $0, $1);
        return len;
    }, buf, buf_len);
}
