const std = @import("std");
const unicode = std.unicode;

pub const Str = struct {
    const Self = @This();

    /// A buffer which contains bytes of UTF-8 encoded text
    u8: []u8,
    allocator: std.mem.Allocator,

    /// Initializes a new string, cloning the data of `str` using `allocator`.
    /// Parameter `str` can be `Str`, `u8` slice or `u8` literal.
    pub fn init(allocator: std.mem.Allocator, str: anytype) !Self {
        const src_buf = StringUtils.getCharBuffer(str);
        const buf = try allocator.alloc(u8, src_buf.len);
        @memcpy(buf, src_buf);
        return Self{
            .u8 = buf,
            .allocator = allocator,
        };
    }

    /// Initializes a new string with formatted data using `allocator`.
    /// See ```std.fmt.format()``` for an explanation of `fmt` string format.
    pub fn initFmt(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !Self {
        const buf = try std.fmt.allocPrint(allocator, fmt, args);
        return Self{
            .u8 = buf,
            .allocator = allocator,
        };
    }

    /// Frees underlying buffer and deallocates data
    pub inline fn deinit(self: Self) void {
        self.allocator.free(self.u8);
    }

    /// Allocates a new string with an exact copy of the contents of this string
    pub fn clone(self: Self) !Self {
        const buf = try self.allocator.alloc(u8, self.u8.len);
        @memcpy(buf, self.u8);
        return Self{
            .u8 = buf,
            .allocator = self.allocator,
        };
    }

    /// Appends `append_str` to the end of string.
    /// Parameter `append_str` can be `Str`, `u8` slice or `u8` literal.
    pub fn concat(self: *Self, append_str: anytype) !void {
        const append_buf = StringUtils.getCharBuffer(append_str);
        if (append_buf.len == 0) return;

        const prev_len = self.u8.len;
        self.u8 = try self.allocator.realloc(self.u8, self.u8.len + append_buf.len);

        @memcpy(self.u8[prev_len..], append_buf);
    }

    /// Checks if string data has valid UTF-8 encoding
    pub inline fn isValidUTF8(self: Self) bool {
        return unicode.wtf8ValidateSlice(self.u8);
    }

    /// Returns an iterator of all UTF-8 code points (runes) in the string.
    /// Will return an error if the string contains invalid UTF-8 data.
    /// ```zig
    /// var iter = try str.iterator();
    /// while (iter.nextCodepointSlice()) |char| {
    ///     std.debug.print("got codepoint '{s}'\n", .{char});
    /// }
    /// ```
    pub fn iterator(self: Self) !StrIterator {
        if (!self.isValidUTF8()) {
            return error.InvalidUtf8;
        }
        return self.iteratorUnchecked();
    }

    /// Returns an iterator of all UTF-8 code points (runes) in the string.
    ///
    /// **No checks of validity of underlying UTF-8 data will be performed.**
    /// Caller must guarantee that current string data is a valid UTF-8 string,
    /// otherwise iterator behaviour is undefined.
    ///
    /// See `Str.iterator()` for an example usage.
    pub inline fn iteratorUnchecked(self: Self) StrIterator {
        return StrIterator{
            .bytes = self.u8,
            .cursor = 0,
        };
    }

    /// Removes all whitespace and line terminator symbols
    /// from both ends of this string
    pub fn trim(self: *Self) void {
        if (self.u8.len == 0 or !self.isValidUTF8()) return;

        var start_byte_offset: usize = 0;
        var end_byte_offset: usize = self.u8.len;

        var it = self.iteratorUnchecked();
        find_start: while (it.nextCodepoint()) |cp| {
            if (!Codepoint.isWhitespaceOrLineTerminator(cp)) {
                break :find_start;
            }
            start_byte_offset = it.cursor;
        }

        var new_len: usize = 0;
        if (start_byte_offset != self.u8.len) {
            it.seekEnd();
            find_end: while (it.prevCodepoint()) |cp| {
                if (!Codepoint.isWhitespaceOrLineTerminator(cp)) {
                    break :find_end;
                }
                end_byte_offset = it.cursor;
            }

            new_len = end_byte_offset - start_byte_offset;
            if (start_byte_offset != 0) {
                for (0..new_len) |i| {
                    self.u8[i] = self.u8[i + start_byte_offset];
                }
            }
        }

        // Because `new_len` is always equal or less that old length,
        // it is ok to ignore if the resizing fails.
        // The poiter address will not change, so even after
        // unsuccessful resize memory will be freed correctly in `deinit()`
        _ = self.allocator.resize(self.u8, new_len);
        self.u8 = self.u8[0..new_len];
    }

    /// Returns the number of UTF-8 scalars in this string.
    /// One UTF-8 scalar may be up to 4 bytes long, so for non-ASCII strings
    /// this is preffered way of obtaining actual length of a string
    /// (instead of `len`, which represents the byte count).
    ///
    /// **NOTE** In some languages, one individual visual character may be
    /// constructed using many UTF-8 scalars, combined into a "grapheme cluster".
    /// This function does not count grapheme clusters because of its computational
    /// complexity.
    /// For a detailed explanation see `https://exploringjs.com/js/book/ch_unicode.html`
    pub fn charCount(self: Self) usize {
        var len: usize = 0;
        var i: usize = 0;
        while (i < self.u8.len) {
            len += 1;
            const cp_len = unicode.utf8ByteSequenceLength(self.u8[i]) catch unreachable;
            i += cp_len;
        }
        return len;
    }
};

const StrIterator = struct {
    const Self = @This();

    /// Current iterator position in string byte array (`bytes`)
    cursor: usize,
    /// String data as UTF-8 byte array slice
    bytes: []const u8,

    /// Returns next codepoint as `[]u8` slice or null if there's no more
    /// codepoints in the string.
    pub fn nextCodepointSlice(self: *Self) ?[]const u8 {
        if (self.cursor >= self.bytes.len) {
            return null;
        }

        const cp_len = unicode.utf8ByteSequenceLength(self.bytes[self.cursor]) catch unreachable;
        self.cursor += cp_len;
        return self.bytes[self.cursor - cp_len .. self.cursor];
    }

    /// Returns next codepoint as `u21` or null if there's no more
    /// codepoints in the string.
    pub fn nextCodepoint(self: *Self) ?u21 {
        const slice = self.nextCodepointSlice() orelse return null;
        return unicode.wtf8Decode(slice) catch unreachable;
    }

    /// Returns previous (prior to current `byte_pos`) codepoint as `[]u8` slice,
    /// or null if `byte_pos` is already at the start of the string.
    pub fn prevCodepointSlice(self: *Self) ?[]const u8 {
        if (self.cursor <= 0) {
            return null;
        }
        if (self.cursor >= self.bytes.len) {
            self.cursor = self.bytes.len - 1;
        }

        var prev_codepoint_start = self.cursor;
        prev_codepoint_start -= 1;

        // Decrement prev_codepoint_start until we find a byte that does not
        // start with 0b10xxxxxx (continuation marker)
        while (self.bytes[prev_codepoint_start] & 0xc0 == 0x80) {
            if (prev_codepoint_start <= 0) {
                self.cursor = 0;
                return null;
            }
            prev_codepoint_start -= 1;
        }

        const cp_len = unicode.utf8ByteSequenceLength(
            self.bytes[prev_codepoint_start],
        ) catch unreachable;
        self.cursor = prev_codepoint_start;
        return self.bytes[self.cursor .. self.cursor + cp_len];
    }

    /// Returns previous (prior to current `byte_pos`) codepoint as `u21`,
    /// or null if `byte_pos` is already at the start of the string.
    pub fn prevCodepoint(self: *Self) ?u21 {
        const slice = self.prevCodepointSlice() orelse return null;
        return unicode.wtf8Decode(slice) catch unreachable;
    }

    /// Sets iterator's cursor to the start of the string
    pub inline fn seekStart(self: *Self) void {
        self.cursor = 0;
    }

    /// Sets iterator's cursor to the end of the string
    pub inline fn seekEnd(self: *Self) void {
        self.cursor = self.bytes.len;
    }
};

test "Str struct tests" {
    _ = @import("tests/str.test.zig");
}

const StringUtils = struct {
    pub fn ensureCorrectStringInitializer(str_type: type) void {
        if (str_type == Str) {
            return;
        }
        if (str_type == []const u8) {
            return;
        }
        const is_pointer_to_literal = comptime blk: {
            const type_info = @typeInfo(str_type);
            if (type_info != .Pointer) {
                break :blk false;
            }
            const deref_type_info = @typeInfo(type_info.Pointer.child);
            if (deref_type_info != .Array) {
                break :blk false;
            }
            if (deref_type_info.Array.child != u8) {
                break :blk false;
            }
            break :blk true;
        };
        if (is_pointer_to_literal) {
            return;
        }
        const error_msg = std.fmt.comptimePrint(
            "Incorrect type of parameter `str`, expected String, u8 slice or u8 literal, got: {s}\n",
            .{@typeName(str_type)},
        );
        @compileError(error_msg);
    }
    pub fn getCharBuffer(str: anytype) []const u8 {
        comptime {
            ensureCorrectStringInitializer(@TypeOf(str));
        }
        const StrType = @TypeOf(str);
        if (StrType == Str) {
            return str.u8;
        }
        return str;
    }
};

/// Various utility functions for UTF-8 codepoints
pub const Codepoint = struct {
    /// Checks if given UTF-8 codepoint is a whitespace or a line terminator
    /// (according to `https://developer.mozilla.org/en-US/docs/Glossary/Whitespace#in_javascript`)
    pub fn isWhitespaceOrLineTerminator(char: u21) bool {
        // Loosely based on V8 implementation,
        // see https://github.com/v8/v8/blob/239c81a23bb79a28cf47f04f035f0664b4d31e8a/src/builtins/string-trim.tq
        if (char == 0x0020) { // 0x0020 - SPACE
            return true;
        }

        const i21_char: i21 = @intCast(char);
        // Common Non-whitespace characters from (0x000E, 0x00A0)
        if (@as(u21, @bitCast(i21_char - 0x000E)) < 0x0092) {
            return false;
        }

        if (char == 0x0009) { // 0x0009 - HORIZONTAL TAB
            return true;
        }

        // 0x000A - LINE FEED OR NEW LINE
        // 0x000B - VERTICAL TAB
        // 0x000C - FORMFEED
        // 0x000D - HORIZONTAL TAB
        if (char <= 0x000D) {
            return true;
        }

        if (char == 0x00A0) { // 0x00A0 - NO-BREAK SPACE
            return true;
        }

        if (char == 0x1680) { // 0x1680 - Ogham Space Mark
            return true;
        }

        if (char < 0x2000) { // 0x2000 - EN QUAD
            return false;
        }
        // 0x2001 - EM QUAD
        // 0x2002 - EN SPACE
        // 0x2003 - EM SPACE
        // 0x2004 - THREE-PER-EM SPACE
        // 0x2005 - FOUR-PER-EM SPACE
        // 0x2006 - SIX-PER-EM SPACE
        // 0x2007 - FIGURE SPACE
        // 0x2008 - PUNCTUATION SPACE
        // 0x2009 - THIN SPACE
        // 0x200A - HAIR SPACE
        if (char <= 0x200A) {
            return true;
        }

        if (char == 0x2028) { // 0x2028 - LINE SEPARATOR
            return true;
        }
        if (char == 0x2029) { // 0x2029 - PARAGRAPH SEPARATOR
            return true;
        }
        if (char == 0x202F) { // 0x202F - NARROW NO-BREAK SPACE
            return true;
        }
        if (char == 0x205F) { // 0x205F - MEDIUM MATHEMATICAL SPACE
            return true;
        }
        if (char == 0xFEFF) { // 0xFEFF - BYTE ORDER MARK
            return true;
        }
        if (char == 0x3000) { // 0x3000 - IDEOGRAPHIC SPACE
            return true;
        }
        return false;
    }

    /// Returns how many bytes the UTF-8 representation would require
    /// for the given codepoint.
    pub inline fn byteLength(char: u21) !u3 {
        return unicode.utf8CodepointSequenceLength(char);
    }

    /// Tries to decode UTF-8 codepoint from given u8 slice.
    /// Returns error if slice does not contain a valid UTF-8 codepoint.
    pub inline fn fromSlice(utf8char: []const u8) !u21 {
        return unicode.wtf8Decode(utf8char);
    }
};
