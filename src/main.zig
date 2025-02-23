const std = @import("std");
const Str = @import("composable-string.zig").Str;

pub fn main() !void {
    std.debug.print("composable-string {}\n\n", .{@import("build_options").lib_version});
    const a = std.heap.c_allocator;

    var str = try Str.init(a, "Hello composable-string!");
    defer str.deinit();
    try str.concat(" (this is concatenated string literal)");

    var another = try Str.init(a, " (this is concatenated Str)");
    defer another.deinit();
    try str.concat(another);
    std.debug.print("'str' is: \"{s}\"\n\n", .{str.asSlice()});

    var str_with_spaces = try Str.initFmt(a, "        A string with {s} \t\n\t\n  ", .{"whitespaces, newlines and tabs"});
    defer str_with_spaces.deinit();
    str_with_spaces.trim();
    std.debug.print("'str_with_spaces' after trim(): \"{s}\"\n", .{str_with_spaces.asSlice()});

    var non_ascii = try Str.init(a, "Один, 二, さん"); // character count: 11
    defer non_ascii.deinit();
    std.debug.print(
        "\nNon-ascii string: \"{s}\", string.byteCount(): {}, string.charCount(): {}\n",
        .{ non_ascii.asSlice(), non_ascii.byteCount(), non_ascii.charCount() },
    );
}
