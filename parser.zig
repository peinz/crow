const std = @import("std");
const ast = @import("./ast.zig");
const p_ts = @import("./parser-tokenstream.zig");

const Allocator = std.mem.Allocator;
const Token = p_ts.Token;
const TokenStream = p_ts.TokenStream;

const SyntaxError = error{
    UnexpectedPunctuation,
    UnexpectedToken,
    UnexpectedEndOfFile,
};

pub const Parser = struct {
    allocator: Allocator,
    token_str: *TokenStream,

    pub fn init(allocator: Allocator) !Parser {
        var token_str = try allocator.create(TokenStream);

        return Parser{
            .allocator = allocator,
            .token_str = token_str,
        };
    }

    fn report(self: @This(), error_type: SyntaxError) noreturn {
        const stdout = std.io.getStdOut().writer();
        const state = self.token_str.inp_str;
        stdout.print("pos: {d}, line: {d}, col: {d}, char: {c} ({d})\n", .{ state.pos.*, state.line.*, state.col.*, state.char.*, state.char.* }) catch unreachable;
        stdout.print("{s}\n", .{self.token_str.curr.*}) catch unreachable;
        const text = switch (error_type) {
            SyntaxError.UnexpectedPunctuation => "UnexpectedPunctuation",
            SyntaxError.UnexpectedToken => "UnexpectedToken",
            SyntaxError.UnexpectedEndOfFile => "UnexpectedEndOfFile",
        };
        @panic(text);
    }

    fn parseExpression(self: @This()) *const ast.Expression {
        const is_number = self.token_str.curr.* == Token.number;
        const is_identifier = self.token_str.curr.* == Token.identifier;
        if (!is_number and !is_identifier) {
            self.report(SyntaxError.UnexpectedToken);
        }

        const exp1 = self.allocator.create(ast.Expression) catch unreachable;
        exp1.* = switch (is_number) {
            true => ast.Expression{
                .literal = ast.Literal{
                    .value = self.token_str.curr.number,
                },
            },
            false => ast.Expression{
                .variable = ast.Variable{
                    .name = self.token_str.curr.identifier,
                },
            },
        };

        self.token_str.readNextToken();

        if (self.token_str.curr.* == Token.punctuation and self.token_str.curr.punctuation == .expression_end) {
            self.token_str.readNextToken();
            return exp1;
        }

        if (self.token_str.curr.* != Token.oparator) {
            self.report(SyntaxError.UnexpectedToken);
        }

        const opr = self.token_str.curr.oparator;

        self.token_str.readNextToken();

        const exp = self.allocator.create(ast.Expression) catch unreachable;
        exp.* = ast.Expression{
            .binaryExpression = ast.BinaryExpression{
                .opr = opr,
                .lhs = exp1,
                .rhs = self.parseExpression(),
            },
        };

        return exp;
    }

    fn parseValDecl(self: @This()) ast.ConstantDeclaration {
        if (self.token_str.curr.* != Token.keyword or self.token_str.curr.keyword != .val_decl) {
            return self.report(SyntaxError.UnexpectedToken);
        }

        self.token_str.readNextToken();

        if (self.token_str.curr.* != Token.identifier) {
            self.report(SyntaxError.UnexpectedToken);
        }
        var decl_name = self.allocator.alloc(u8, self.token_str.curr.identifier.len) catch unreachable;
        decl_name = self.token_str.curr.identifier;

        self.token_str.readNextToken();

        if (self.token_str.curr.* != Token.oparator or self.token_str.curr.oparator != .assignment) {
            return self.report(SyntaxError.UnexpectedToken);
        }

        self.token_str.readNextToken();

        return ast.ConstantDeclaration{
            .constantName = decl_name,
            .expression = self.parseExpression(),
        };
    }

    fn parseStatement(self: @This()) ast.Statement {
        return switch (self.token_str.curr.*) {
            .keyword => switch (self.token_str.curr.keyword) {
                .val_decl => {
                    return ast.Statement{
                        .constantDeclaration = self.parseValDecl(),
                    };
                },
                ._return => {
                    self.token_str.readNextToken();
                    return ast.Statement{
                        .returnStatement = ast.ReturnStatement{
                            .expression = self.parseExpression(),
                        },
                    };
                },
            },
            else => self.report(SyntaxError.UnexpectedToken),
        };
    }

    fn parseBlock(self: @This()) !ast.Block {
        if (self.token_str.curr.* != Token.punctuation or self.token_str.curr.punctuation != .curlyBracket_open) {
            return self.report(SyntaxError.UnexpectedToken);
        }
        self.token_str.readNextToken();

        var statements = std.ArrayList(ast.Statement).init(self.allocator);
        while (true) {
            if (self.token_str.curr.* == Token.punctuation and self.token_str.curr.punctuation == .curlyBracket_close) {
                break;
            }

            if (self.token_str.inp_str.eof.*) {
                self.report(SyntaxError.UnexpectedEndOfFile);
            }

            var statement = self.parseStatement();
            try statements.append(statement);
        }
        return ast.Block{ .statements = statements };
    }

    pub fn parse(self: @This(), comptime filePath: []const u8) !ast.Block {
        var file = try std.fs.cwd().openFile(filePath, .{});
        self.token_str.* = try TokenStream.init(self.allocator, file.reader());
        self.token_str.curr.* = Token{ .startOfFile = 1 };
        defer file.close();

        if (self.token_str.curr.* == Token.startOfFile) {
            self.token_str.readNextToken();
        }
        return switch (self.token_str.curr.*) {
            .punctuation => switch (self.token_str.curr.punctuation) {
                .curlyBracket_open => try self.parseBlock(),
                else => self.report(SyntaxError.UnexpectedPunctuation),
            },
            else => self.report(SyntaxError.UnexpectedToken),
        };
    }
};
