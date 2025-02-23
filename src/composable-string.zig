const std = @import("std");
const unicode = std.unicode;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

/// A UTF-8–encoded, growable string.
///
/// Example:
/// ```zig
///    // Use your favorite allocator
///    const a = std.heap.c_allocator;
///
///    var str = try Str.init(a, "Hello");
///    defer str.deinit();
///    try str.concat(", composable-string!");
///
///    var another = try Str.initFmt(a, " (this is {s} {s})", .{"concatinated", "Str"});
///    defer another.deinit();
///    try str.concat(another);
///    std.debug.print("str = \"{s}\"\n", .{ str });
/// ```
///
///
/// # Representation
///
/// A `Str` is made up of `std.ArrayListUnmanaged` and an `std.mem.Allocator`.
/// `Str` is always stored on the heap.
///
/// Similarly to `std.ArrayList`, `Str` has a pointer to data (`u8` buffer), length and capacity.
/// The length is the number of bytes currently stored in the buffer,
/// and the capacity is the size of the buffer in bytes.
/// As such, the length will always be less than or equal to the capacity.
///
///
/// # UTF-8
///
/// All `Str`'s methods enforce valid UTF-8.
///
/// Thereby it is not recommended to manually mutate the `buf` field (although it is possible).
/// When doing any changes to the underlying `buf` field, one should guarantee the UTF-8 validity of
/// the content.
pub const Str = struct {
    const Self = @This();

    pub const Error = error{
        /// Indicates that there was an attempt to construct `Str`
        /// from some input parameter which contains invalid UTF-8 sequence.
        InvalidUtf8,

        /// Indicates that input parameter is of incorrect type
        /// and cannot be trivially converted to `Str`.
        IncorrectParameterType,

        /// Indicates that underlying allocator was unable to allocate more memory.
        /// Same as `std.mem.Allocator.Error`
        OutOfMemory,
    };

    /// A buffer which contains the bytes of UTF-8 encoded text.
    ///
    /// When doing any changes, one should guarantee the UTF-8 validity of
    /// the content in this buffer.
    buf: ArrayListUnmanaged(u8),

    /// Allocator for working with underlying byte buffer (`buf`).
    allocator: std.mem.Allocator,

    /// Initializes a new string, cloning the data of `str` using `allocator`.
    /// Parameter `str` can be `Str`, `u8` slice or `u8` literal.
    pub fn init(allocator: std.mem.Allocator, str: anytype) !Self {
        const src_buf = StringUtils.getUnderlyingU8Slice(str);
        try Self.checkValidUTF8(src_buf);

        var buf = try ArrayListUnmanaged(u8).initCapacity(allocator, src_buf.len);
        buf.appendSliceAssumeCapacity(src_buf);

        return Self{
            .buf = buf,
            .allocator = allocator,
        };
    }

    /// Initializes a new string with formatted data using `allocator`.
    /// See ```std.fmt.format()``` for an explanation of `fmt` string format.
    pub fn initFmt(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !Self {
        const char_count = std.fmt.count(fmt, args);
        var buf = try ArrayListUnmanaged(u8).initCapacity(allocator, char_count);
        buf.items = try std.fmt.bufPrint(buf.allocatedSlice(), fmt, args);

        Self.checkValidUTF8(buf.items) catch |err| {
            buf.deinit(allocator);
            return err;
        };
        return Self{
            .buf = buf,
            .allocator = allocator,
        };
    }

    /// Initializes a new string with an empty buffer.
    pub fn initEmpty(allocator: std.mem.Allocator) Self {
        const buf = ArrayListUnmanaged(u8).empty;
        return Self{
            .buf = buf,
            .allocator = allocator,
        };
    }

    /// Returns this `Str` capacity, in bytes.
    /// Capacity is the length of allocated buffer in memory.
    pub inline fn capacity(self: Self) usize {
        return self.buf.capacity;
    }

    /// Modify `Str` underlying buffer so that it can hold at least `new_capacity` bytes.
    pub inline fn ensureTotalCapacity(self: *Self, new_capacity_bytes: usize) Str.Error!void {
        self.buf.ensureTotalCapacity(self.allocator, new_capacity_bytes) catch {
            return Str.Error.OutOfMemory;
        };
    }

    /// Sets the content of this string by copying data from `new_content`.
    /// Parameter `new_content` can be `Str`, `u8` slice or `u8` literal.
    ///
    /// This function changes this `Str`s capacity to `new_content.len` by resizing allocated byte buffer.
    pub fn set(self: *Self, new_content: anytype) !void {
        const content_buf = StringUtils.getUnderlyingU8Slice(new_content);
        if (content_buf.len == 0) {
            self.clear();
            return;
        }
        try Self.checkValidUTF8(content_buf);

        if (content_buf.len > self.buf.capacity) {
            try self.buf.ensureTotalCapacityPrecise(self.allocator, content_buf.len);
        } else if (content_buf.len < self.buf.capacity) {
            self.buf.shrinkAndFree(self.allocator, content_buf.len);
        }
        // At this point, `self.buf` capacity should be exactly `content_buf.len`
        self.buf.items = self.buf.allocatedSlice();
        @memcpy(self.buf.items, content_buf);
    }

    /// Truncates this string, removing all the contents.
    /// Also shrinks the allocated buffer, so capacity becomes 0.
    pub inline fn clear(self: *Self) void {
        self.buf.clearAndFree(self.allocator);
    }

    /// Truncates this string, removing all the contents, but keeping the capacity.
    /// Underlying buffer size keeps untouched.
    pub inline fn clearRetainingCapacity(self: *Self) void {
        self.buf.clearRetainingCapacity();
    }

    /// Free underlying buffer and release all allocated memory
    pub inline fn deinit(self: *Self) void {
        self.buf.deinit(self.allocator);
        self.* = undefined;
    }

    /// Allocates a new Str with an exact copy of the contents of this string
    pub fn clone(self: Self) !Self {
        const buf = try self.buf.clone(self.allocator);
        return Self{
            .buf = buf,
            .allocator = self.allocator,
        };
    }

    /// Appends `append_str` to the end of string.
    /// Parameter `append_str` can be `Str`, `u8` slice or `u8` literal.
    pub fn concat(self: *Self, append_str: anytype) !void {
        const append_buf = StringUtils.getUnderlyingU8Slice(append_str);
        if (append_buf.len == 0) return;
        try Self.checkValidUTF8(append_buf);

        try self.buf.appendSlice(self.allocator, append_buf);
    }

    /// Appends formatted string to the end this `Str`.
    /// See ```std.fmt.format()``` for an explanation of `fmt` string format.
    pub fn concatFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const original_len = self.byteCount();
        const original_capacity = self.capacity();

        const char_count = std.fmt.count(fmt, args);
        self.buf.ensureUnusedCapacity(self.allocator, char_count) catch {
            return Str.Error.OutOfMemory;
        };

        const new_allocated_slice = self.buf.allocatedSlice();
        const buf_u8 = new_allocated_slice[original_len..(original_len + char_count)];
        _ = try std.fmt.bufPrint(buf_u8, fmt, args);

        Self.checkValidUTF8(buf_u8) catch |err| {
            self.buf.items = new_allocated_slice[0..original_len];
            self.buf.shrinkAndFree(self.allocator, original_capacity);
            return err;
        };

        self.buf.items = new_allocated_slice[0..(original_len + char_count)];
    }

    /// Checks if string data has valid UTF-8 encoding
    inline fn checkValidUTF8(str: anytype) Str.Error!void {
        const slice = StringUtils.getUnderlyingU8Slice(str);
        if (!unicode.wtf8ValidateSlice(slice)) {
            return Str.Error.InvalidUtf8;
        }
    }

    /// Returns an iterator of all UTF-8 code points (runes) in the string.
    /// ```
    /// var iter = try str.iterator();
    /// while (iter.nextCodepointSlice()) |char| {
    ///     std.debug.print("got codepoint '{s}'\n", .{char});
    /// }
    /// ```
    /// Contents of this `Str` should never mutate while using an iterator.
    pub fn iterator(self: Self) !StrIterator {
        try self.checkValidUTF8();
        return self.iteratorUnchecked();
    }

    /// Returns an iterator of all UTF-8 code points (runes) in the string.
    ///
    /// *No checks of validity of underlying UTF-8 data will be performed.*
    /// Caller must guarantee that current string data is a valid UTF-8 string,
    /// otherwise iterator behaviour is undefined.
    ///
    /// See `Str.iterator()` for an example usage.
    pub inline fn iteratorUnchecked(self: Self) StrIterator {
        return StrIterator{
            .bytes = self.buf.items,
            .cursor = 0,
        };
    }

    /// Removes all whitespace and line terminator symbols
    /// from the beginning of this string
    pub fn trimStart(self: *Self) void {
        if (self.byteCount() == 0) return;
        self.checkValidUTF8() catch {
            return;
        };

        var start_byte_offset: usize = 0;

        var it = self.iteratorUnchecked();
        find_start: while (it.nextCodepoint()) |cp| {
            if (!Codepoint.isWhitespaceOrLineTerminator(cp)) {
                break :find_start;
            }
            start_byte_offset = it.cursor;
        }

        var new_len: usize = 0;
        if (it.nextCodepoint() != null) {
            new_len = self.byteCount() - start_byte_offset;
            if (start_byte_offset != 0) {
                for (0..new_len) |i| {
                    self.buf.items[i] = self.buf.items[i + start_byte_offset];
                }
            }
        }

        self.shrinkDown(new_len);
    }

    /// Removes all whitespace and line terminator symbols
    /// from the end of this string
    pub fn trimEnd(self: *Self) void {
        if (self.byteCount() == 0) return;
        self.checkValidUTF8() catch {
            return;
        };

        var end_byte_offset: usize = self.buf.items.len;

        var it = self.iteratorUnchecked();
        it.seekEnd();
        find_end: while (it.prevCodepoint()) |cp| {
            if (!Codepoint.isWhitespaceOrLineTerminator(cp)) {
                break :find_end;
            }
            end_byte_offset = it.cursor;
        }

        const new_len = @max(0, end_byte_offset);
        self.shrinkDown(new_len);
    }

    /// Removes all whitespace and line terminator symbols
    /// from both ends of this string
    pub fn trim(self: *Self) void {
        if (self.byteCount() == 0) return;
        self.checkValidUTF8() catch {
            return;
        };

        var start_byte_offset: usize = 0;
        var end_byte_offset: usize = self.byteCount();

        var it = self.iteratorUnchecked();
        find_start: while (it.nextCodepoint()) |cp| {
            if (!Codepoint.isWhitespaceOrLineTerminator(cp)) {
                break :find_start;
            }
            start_byte_offset = it.cursor;
        }

        var new_len: usize = 0;
        if (it.nextCodepoint() != null) { // start position is not at the end of string
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
                    self.buf.items[i] = self.buf.items[i + start_byte_offset];
                }
            }
        }

        self.shrinkDown(new_len);
    }

    /// Returns the underlying `u8` slice of the string.
    ///
    /// Pointers to elements in this slice are invalidated by any
    /// function which mutate the data of this `Str`.
    pub inline fn asSlice(self: Self) []const u8 {
        return self.buf.items;
    }

    /// Returns the length in bytes of the current string.
    ///
    /// For obtaining actual length (i. e. number of characters) in the string,
    /// `Str.charCount` should be used instead. For non-ASCII strings, one UTF-8 scalar
    /// may be up to 4 bytes long, so `Str.byteLength` may not correspond with actual character count.
    pub inline fn byteCount(self: Self) usize {
        return self.buf.items.len;
    }

    /// Returns the number of actual characters (UTF-8 scalars) in this string.
    /// One UTF-8 scalar may be up to 4 bytes long, so for non-ASCII strings
    /// this is preffered way of obtaining actual length of a string.
    ///
    /// **NOTE** In some languages, one individual visual character may be
    /// constructed using many UTF-8 scalars, combined into a "grapheme cluster".
    /// This function does not count grapheme clusters because of its computational
    /// complexity.
    /// For a detailed explanation see `https://exploringjs.com/js/book/ch_unicode.html`
    pub fn charCount(self: Self) usize {
        var len: usize = 0;
        var i: usize = 0;
        while (i < self.buf.items.len) {
            len += 1;
            const cp_len = unicode.utf8ByteSequenceLength(self.buf.items[i]) catch unreachable;
            i += cp_len;
        }
        return len;
    }

    /// Implements default formatting for `Str`. Example:
    /// ```zig
    /// const str = try Str.init(a, "Hello");
    /// std.debug.print("str = {s}", .{ str }); // Expected output: "str = Hello"
    /// ```
    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, fmt_writer: anytype) !void {
        _ = fmt;
        _ = options;

        try fmt_writer.print("{s}", .{self.buf.items});
    }

    pub const Writer = std.io.Writer(*Self, Str.Error, appendWrite);

    /// Initializes a Writer which will append to this `Str`.
    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    /// The purpose of this function existing is to match `std.io.Writer` API.
    /// Contents of the `m` buffer should be valid UTF-8 data.
    fn appendWrite(self: *Self, m: []const u8) Str.Error!usize {
        try Self.checkValidUTF8(m);
        self.buf.appendSlice(self.allocator, m) catch {
            return Str.Error.OutOfMemory;
        };
        return m.len;
    }

    pub const FixedWriter = std.io.Writer(*Self, Str.Error, appendWriteFixed);

    /// Initializes a Writer which will append to this `Str` but will return
    /// `error.OutOfMemory` rather than increasing capacity of th `Str`.
    pub fn fixedWriter(self: *Self) FixedWriter {
        return .{ .context = self };
    }

    /// The purpose of this function existing is to match `std.io.Writer` API.
    /// Contents of the `m` buffer should be valid UTF-8 data.
    fn appendWriteFixed(self: *Self, m: []const u8) Str.Error!usize {
        const available_capacity = self.capacity() - self.byteCount();
        if (m.len > available_capacity)
            return Str.Error.OutOfMemory;

        try Self.checkValidUTF8(m);
        self.buf.appendSliceAssumeCapacity(m);
        return m.len;
    }

    /// (internal) Shrinks internal byte buffer to a new size.
    /// Caller must guarantee that `new_byte_len <= self.u8.len`.
    inline fn shrinkDown(self: *Self, new_byte_len: usize) void {
        self.buf.shrinkAndFree(self.allocator, new_byte_len);
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
    pub fn checkTypeIsStringLike(str_type: type) bool {
        if (str_type == Str or str_type == *Str) {
            return true;
        }
        if (str_type == []const u8) {
            return true;
        }
        if (str_type == []u8) {
            return true;
        }
        const is_pointer_to_literal = comptime blk: {
            const type_info = @typeInfo(str_type);
            if (type_info != .pointer) {
                break :blk false;
            }
            const deref_type_info = @typeInfo(type_info.pointer.child);
            if (deref_type_info != .array) {
                break :blk false;
            }
            if (deref_type_info.array.child != u8) {
                break :blk false;
            }
            break :blk true;
        };
        if (is_pointer_to_literal) {
            return true;
        }
        return false;
    }
    pub fn ensureTypeIsStringLike(str_type: type) void {
        if (checkTypeIsStringLike(str_type)) {
            return;
        }
        const error_msg = std.fmt.comptimePrint(
            "Incorrect type. Expected Str, u8 slice or u8 literal, got: {s}\n",
            .{@typeName(str_type)},
        );
        @compileError(error_msg);
    }
    pub fn getUnderlyingU8Slice(str: anytype) []const u8 {
        const StrType = @TypeOf(str);
        comptime {
            ensureTypeIsStringLike(StrType);
        }
        if (StrType == Str or StrType == *Str) {
            return str.buf.items;
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
