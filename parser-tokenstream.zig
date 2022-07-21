const std = @import("std");
const ast = @import("./ast.zig");
const p_is = @import("./parser-inputstream.zig");

const Allocator = std.mem.Allocator;
const InputStream = p_is.InputStream;

pub const Token = union(enum) {
    startOfFile: u8,
    punctuation: enum {
        bracket_open,
        bracket_close,
        curlyBracket_open,
        curlyBracket_close,
        expression_end,
    },
    number: i32,
    keyword: enum {
        val_decl,
        _return,
    },
    oparator: ast.Oparator,
    identifier: []u8,
};

pub const TokenStream = struct {
    allocator: Allocator,
    inp_str: *InputStream,
    curr: *Token,

    pub fn init(allocator: Allocator, in_stream: std.io.Reader(std.fs.File, std.os.ReadError, std.fs.File.read)) !TokenStream {
        var inp_str = try allocator.create(InputStream);
        inp_str.* = try InputStream.init(allocator, in_stream);

        var curr = try allocator.create(Token);

        return TokenStream{
            .allocator = allocator,
            .inp_str = inp_str,
            .curr = curr,
        };
    }

    fn isWhitespace(char: u8) bool {
        return char == ' ' or char == '\t';
    }

    fn isDigit(char: u8) bool {
        return char >= 48 and char < 58;
    }

    fn isOparator(char: u8) bool {
        return switch (char) {
            '+', '-', '*', '=' => true,
            else => false,
        };
    }

    fn isPunctuation(char: u8) bool {
        return switch (char) {
            '(', ')', '{', '}', '\n' => true,
            else => false,
        };
    }

    fn isIdentifier(char: u8) bool {
        return !isWhitespace(char) and !isOparator(char) and char != '\n';
    }

    fn readWhile(self: @This(), read_chars: *[40]u8, continue_reading: fn (char: u8) bool) []u8 {
        var i: u8 = 0;
        while (!self.inp_str.eof.* and continue_reading(self.inp_str.char.*)) {
            read_chars[i] = self.inp_str.char.*;
            self.inp_str.readNextChar();
            i += 1;
        }
        return read_chars[0..i];
    }

    pub fn readNextToken(self: @This()) void {
        var read_chars: [40]u8 = undefined;
        const inp_str = self.inp_str;
        const char = inp_str.char;

        // defer {
        //     const stdout = std.io.getStdOut().writer();
        //     stdout.print("token: {s}\n", .{self.curr.*}) catch unreachable;
        // }

        // skip whitespace
        while (isWhitespace(char.*)) {
            inp_str.readNextChar();
        }

        if (inp_str.eof.*) return;

        // number token
        if (isDigit(char.*)) {
            const str = self.readWhile(&read_chars, isDigit);
            self.curr.* = Token{
                .number = std.fmt.parseInt(i32, str, 0) catch unreachable,
            };
            return;
        }

        // operator token
        if (isOparator(char.*)) {
            const op = self.readWhile(&read_chars, isOparator);
            if (op[0] == '+') {
                self.curr.* = Token{ .oparator = .plus };
                return;
            }
            if (op[0] == '-') {
                self.curr.* = Token{ .oparator = .minus };
                return;
            }
            if (op[0] == '*') {
                self.curr.* = Token{ .oparator = .multiply };
                return;
            }
            if (op[0] == '=') {
                self.curr.* = Token{ .oparator = .assignment };
                return;
            }
        }

        // punctuation
        if (isPunctuation(char.*)) {
            self.curr.* = switch (char.*) {
                '(' => Token{ .punctuation = .bracket_open },
                ')' => Token{ .punctuation = .bracket_close },
                '{' => Token{ .punctuation = .curlyBracket_open },
                '}' => Token{ .punctuation = .curlyBracket_close },
                else => Token{ .punctuation = .expression_end },
            };

            // do not emit statement_end tokens after curly-braces
            const isCurlyBacket = char.* == '{' or char.* == '}';
            inp_str.readNextChar();
            if (isCurlyBacket) {
                while (char.* == '\n' and !inp_str.eof.*) {
                    inp_str.readNextChar();
                }
            }

            return;
        }

        // identefier/keyword token
        const str = self.readWhile(&read_chars, isIdentifier);
        if (std.mem.eql(u8, str, "val")) {
            self.curr.* = Token{ .keyword = .val_decl };
        } else if (std.mem.eql(u8, str, "return")) {
            self.curr.* = Token{ .keyword = ._return };
        } else {
            const id = self.allocator.alloc(u8, str.len) catch unreachable;
            std.mem.copy(u8, id, str[0..str.len]);
            self.curr.* = Token{ .identifier = id[0..str.len] };
        }
    }
};
