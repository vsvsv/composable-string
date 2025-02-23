const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;

test "Str.trimStart should remove all spaces, tabs and line separators from the start of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "     spaces before");
    defer str.deinit();
    str.trimStart();
    try testing.expectEqualStrings("spaces before", str.asSlice());

    // Should do nothing:
    var str_end = try Str.init(a, "spaces at the end    ");
    defer str_end.deinit();
    str_end.trimStart();
    try testing.expectEqualStrings("spaces at the end    ", str_end.asSlice());

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trimStart();
    try testing.expectEqual(wo_str.byteCount(), 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, " \n \t \r example 2");
    defer str2.deinit();
    str2.trimStart();
    try testing.expectEqualStrings("example 2", str2.asSlice());

    // Uncommon UTF-8 space symbols:
    // no-break space; ogham space mark; three-per-em space; four-per-em space; figure space; line separator
    var str3 = try Str.init(a, "\u{a0} \u{1680} \u{2004} \u{2005} \u{2007} \u{2028} unusual spaces");
    defer str3.deinit();
    str3.trimStart();
    try testing.expectEqualStrings("unusual spaces", str3.asSlice());
}

test "Str.trimEnd should remove all spaces, tabs and line separators from the of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "simple spaces    ");
    defer str.deinit();
    str.trimEnd();
    try testing.expectEqualStrings("simple spaces", str.asSlice());

    // Should do nothing:
    var str_start = try Str.init(a, "    spaces before");
    defer str_start.deinit();
    str_start.trimEnd();
    try testing.expectEqualStrings("    spaces before", str_start.asSlice());

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trimEnd();
    try testing.expectEqual(wo_str.byteCount(), 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, "example 2 \t \n \r ");
    defer str2.deinit();
    str2.trimEnd();
    try testing.expectEqualStrings("example 2", str2.asSlice());

    // Uncommon UTF-8 space symbols:
    // [no-break space; ogham space mark] [three-per-em space; four-per-em space; figure space; line separator]
    var str3 = try Str.init(a, "unusual spaces \u{a0} \u{1680} \u{2004} \u{2005} \u{2007} \u{2028}");
    defer str3.deinit();
    str3.trimEnd();
    try testing.expectEqualStrings("unusual spaces", str3.asSlice());
}

test "Str.trim should remove all spaces, tabs and line separators from both ends of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "     simple spaces    ");
    defer str.deinit();
    str.trim();
    try testing.expectEqualStrings("simple spaces", str.asSlice());

    var str_start = try Str.init(a, "     spaces before");
    defer str_start.deinit();
    str_start.trim();
    try testing.expectEqualStrings("spaces before", str_start.asSlice());

    var str_end = try Str.init(a, "spaces at the end    ");
    defer str_end.deinit();
    str_end.trim();
    try testing.expectEqualStrings("spaces at the end", str_end.asSlice());

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trim();
    try testing.expectEqual(wo_str.byteCount(), 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, " \n \t \r example 2 \t \n \r ");
    defer str2.deinit();
    str2.trim();
    try testing.expectEqualStrings("example 2", str2.asSlice());

    // Uncommon UTF-8 space symbols:
    // [no-break space; ogham space mark] [three-per-em space; four-per-em space; figure space; line separator]
    var str3 = try Str.init(a, "\u{a0} \u{1680} unusual spaces \u{2004} \u{2005} \u{2007} \u{2028}");
    defer str3.deinit();
    str3.trim();
    try testing.expectEqualStrings("unusual spaces", str3.asSlice());
}
