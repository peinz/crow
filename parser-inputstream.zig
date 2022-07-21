const std = @import("std");
const Allocator = std.mem.Allocator;

pub const InputStream = struct {
    in_stream: *std.io.Reader(std.fs.File, std.os.ReadError, std.fs.File.read),
    pos: *i32,
    line: *i32,
    col: *i32,
    char: *u8,
    eof: *bool,

    pub fn init(allocator: Allocator, in_stream: std.io.Reader(std.fs.File, std.os.ReadError, std.fs.File.read)) !InputStream {
        const inp_str = InputStream{
            .in_stream = try allocator.create(std.io.Reader(std.fs.File, std.os.ReadError, std.fs.File.read)),
            .char = try allocator.create(u8),
            .eof = try allocator.create(bool),
            .pos = try allocator.create(i32),
            .line = try allocator.create(i32),
            .col = try allocator.create(i32),
        };

        inp_str.in_stream.* = in_stream;
        inp_str.char.* = ' ';
        inp_str.eof.* = false;
        inp_str.pos.* = 0;
        inp_str.line.* = 1;
        inp_str.col.* = 0;

        return inp_str;
    }

    pub fn readNextChar(self: @This()) void {
        var result: [1]u8 = undefined;
        const amt_read = self.in_stream.read(result[0..]) catch {
            self.eof.* = true;
            return;
        };
        if (amt_read < 1) {
            self.eof.* = true;
            return;
        }
        self.char.* = result[0];

        if (self.char.* != '\n') self.col.* += 1 else {
            self.line.* += 1;
            self.col.* = 0;
        }

        self.pos.* += 1;
    }
};
