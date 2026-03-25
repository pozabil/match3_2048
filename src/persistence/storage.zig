const std = @import("std");
const builtin = @import("builtin");

const IS_WEB = builtin.target.os.tag == .emscripten;
const APP_DIR = "match3_2048";
const SAVE_FILE = "save.json";
pub const SAVE_BUF_SIZE: usize = 65536; // 64 KB — well above any realistic save size
const WEB_BUF_SIZE = SAVE_BUF_SIZE;

extern fn web_storage_save(data: [*]const u8, len: c_int) void;
extern fn web_storage_load(buf: [*]u8, buf_len: c_int) c_int;

/// Load raw save bytes. Caller owns returned slice (allocated with allocator).
/// Returns error.NotFound if no save exists.
pub fn load(allocator: std.mem.Allocator) ![]u8 {
    if (IS_WEB) {
        return loadWeb(allocator);
    } else {
        return loadDesktop(allocator);
    }
}

/// Write raw save bytes. Does not take ownership of data.
/// allocator is unused on web (JS handles storage); required on desktop for dir path.
pub fn save(allocator: std.mem.Allocator, data: []const u8) !void {
    if (IS_WEB) {
        saveWeb(data);
    } else {
        try saveDesktop(allocator, data);
    }
}

// ── Desktop ──────────────────────────────────────────────────────────────────

fn saveDirPath(allocator: std.mem.Allocator) ![]const u8 {
    return std.fs.getAppDataDir(allocator, APP_DIR);
}

fn loadDesktop(allocator: std.mem.Allocator) ![]u8 {
    const dir_path = try saveDirPath(allocator);
    defer allocator.free(dir_path);

    var dir = std.fs.openDirAbsolute(dir_path, .{}) catch |err| {
        if (err == error.FileNotFound) return error.NotFound;
        return err;
    };
    defer dir.close();

    const file = dir.openFile(SAVE_FILE, .{}) catch |err| {
        if (err == error.FileNotFound) return error.NotFound;
        return err;
    };
    defer file.close();

    return file.readToEndAlloc(allocator, 1024 * 1024);
}

fn saveDesktop(allocator: std.mem.Allocator, data: []const u8) !void {
    const dir_path = try saveDirPath(allocator);
    defer allocator.free(dir_path);

    // Create directory if it doesn't exist.
    std.fs.makeDirAbsolute(dir_path) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    var dir = try std.fs.openDirAbsolute(dir_path, .{});
    defer dir.close();

    // Write to a temp file then rename — atomic on POSIX, near-atomic on Windows.
    // A crash before rename leaves save.json.tmp (harmless, cleaned on next save).
    const tmp_name = SAVE_FILE ++ ".tmp";
    var tmp = try dir.createFile(tmp_name, .{});
    try writeAllAndClose(&tmp, data);
    try dir.rename(tmp_name, SAVE_FILE);
}

fn writeAllAndClose(file: *std.fs.File, data: []const u8) !void {
    defer file.close();
    try file.writeAll(data);
}

// ── Web ───────────────────────────────────────────────────────────────────────

fn loadWeb(allocator: std.mem.Allocator) ![]u8 {
    // Allocate a temporary buffer, let JS fill it, then return a trimmed copy.
    const tmp = try allocator.alloc(u8, WEB_BUF_SIZE);
    defer allocator.free(tmp);

    const result = web_storage_load(tmp.ptr, @intCast(WEB_BUF_SIZE));
    if (result == -1) return error.NotFound;
    if (result < 0) return error.StorageError;

    const len: usize = @intCast(result);
    const out = try allocator.alloc(u8, len);
    @memcpy(out, tmp[0..len]);
    return out;
}

fn saveWeb(data: []const u8) void {
    web_storage_save(data.ptr, @intCast(data.len));
}

test "writeAllAndClose closes handle when write fails" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var seed = try tmp.dir.createFile("readonly.bin", .{});
        defer seed.close();
        try seed.writeAll("seed");
    }

    var file = try tmp.dir.openFile("readonly.bin", .{});
    _ = writeAllAndClose(&file, "x") catch {};

    try std.testing.expectError(error.BadFileDescriptor, file.stat());
}
