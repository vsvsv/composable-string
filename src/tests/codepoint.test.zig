const std = @import("std");
const testing = std.testing;
const Codepoint = @import("../composable-string.zig").Codepoint;
const common = @import("./common.zig");

const all_upper_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const all_lower_chars = "abcdefghijklmnopqrstuvwxyz";
const all_number_chars = "0123456789";
const all_alphabetic = all_upper_chars ++ all_lower_chars;
const all_alphanumeric = all_alphabetic ++ all_number_chars;

test "Codepoint.Ascii.toAsciiLowercase correctly changes case" {
    for (all_lower_chars, 0..) |lower_char, idx| {
        // should not change
        try testing.expectEqual(Codepoint.Ascii.toAsciiLowercase(lower_char), all_lower_chars[idx]);
    }
    for (all_upper_chars, 0..) |upper_char, idx| {
        try testing.expectEqual(Codepoint.Ascii.toAsciiLowercase(upper_char), all_lower_chars[idx]);
    }
}

test "Codepoint.Ascii.toAsciiUppercase correctly changes case" {
    for (all_lower_chars, 0..) |lower_char, idx| {
        try testing.expectEqual(Codepoint.Ascii.toAsciiUppercase(lower_char), all_upper_chars[idx]);
    }
    for (all_upper_chars, 0..) |upper_char, idx| {
        // should not change
        try testing.expectEqual(Codepoint.Ascii.toAsciiUppercase(upper_char), all_upper_chars[idx]);
    }
}

test "Codepoint.Ascii.changeAsciiCaseUnchecked correctly changes case in both directions" {
    for (all_lower_chars, 0..) |lower_char, idx| {
        try testing.expectEqual(Codepoint.Ascii.changeAsciiCaseUnchecked(lower_char), all_upper_chars[idx]);
    }
    for (all_upper_chars, 0..) |upper_char, idx| {
        try testing.expectEqual(Codepoint.Ascii.changeAsciiCaseUnchecked(upper_char), all_lower_chars[idx]);
    }
}
