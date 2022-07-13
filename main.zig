const std = @import("std");
const expect = std.testing.expect;

const ctx = @import("./context.zig");
const Context = ctx.Context;

const ConstantDeclaration = struct {
    constantName: []const u8,
    expression: *const Expression,
};

const ReturnStatement = struct {
    expression: *const Expression,
};

const Operator = enum {
    Plus,
    Minus,
    Multiply,
    Divide,
    Modulo,
};

const Literal = struct {
    value: i32,
};

const Variable = struct {
    name: []const u8,
};

const BinaryExpression = struct {
    lhs: *const Expression,
    rhs: *const Expression,
    opr: Operator,
};

const Block = struct {
    statements: []const Statement,
};

const FooErrors = error{
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    AccessDenied,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    NotOpenForWriting,
    WouldBlock,
    ConnectionResetByPeer,
    Unexpected,
};

fn printIndented(comptime format: []const u8, args: anytype, indent: i8) FooErrors!void {
    const stdout = std.io.getStdOut().writer();
    var i: u8 = 0;
    while (i < indent) {
        i += 1;
        try stdout.print(" ", .{});
    }
    try stdout.print(format, args);
}

const Expression = union(enum) {
    literal: Literal,
    variable: Variable,
    binaryExpression: BinaryExpression,
    block: Block,
    pub fn evaluate(self: @This(), context: Context) i32 {
        return switch (self) {
            .literal => self.literal.value,
            .variable => context.get(self.variable.name),
            .binaryExpression => {
                const lhsResult = self.binaryExpression.lhs.evaluate(context);
                const rhsResult = self.binaryExpression.rhs.evaluate(context);
                return switch (self.binaryExpression.opr) {
                    .Plus => lhsResult + rhsResult,
                    .Minus => lhsResult - rhsResult,
                    .Multiply => lhsResult * rhsResult,
                    .Divide => @divFloor(lhsResult, rhsResult),
                    .Modulo => @mod(lhsResult, rhsResult),
                };
            },
            .block => {
                var result: i32 = 0;
                // TODO: scopedContext = context.spawnNewContext();
                for (self.block.statements) |statement| {
                    if (statement == Statement.constantDeclaration) {
                        const name = statement.constantDeclaration.constantName;
                        const value = statement.constantDeclaration.expression.evaluate(context);
                        context.set(name, value);
                    }
                    if (statement == Statement.returnStatement) {
                        result = statement.returnStatement.expression.evaluate(context);
                    }
                }
                return result;
            },
        };
    }
    pub fn dump(self: @This(), indent: i8) FooErrors!void {
        _ = indent;
        _ = switch (self) {
            .literal => try printIndented("literal({d})\n", .{self.literal.value}, indent),
            .variable => try printIndented("variable('{s}')\n", .{self.variable.name}, indent),
            .binaryExpression => {
                try printIndented("binaryExpression('{s}')\n", .{self.binaryExpression.opr}, indent);
                try printIndented("lhs:\n", .{}, indent + 2);
                try self.binaryExpression.lhs.dump(indent + 4);
                try printIndented("rhs:\n", .{}, indent + 2);
                try self.binaryExpression.rhs.dump(indent + 4);
            },
            .block => {
                try printIndented("block\n", .{}, indent);
                for (self.block.statements) |statement| {
                    if (statement == Statement.constantDeclaration) {
                        try printIndented("- constantDeclaration('{s}')\n", .{statement.constantDeclaration.constantName}, indent + 2);
                        try statement.constantDeclaration.expression.dump(indent + 6);
                    }
                    if (statement == Statement.returnStatement) {
                        try printIndented("- returnStatement\n", .{}, indent + 2);
                        try statement.returnStatement.expression.dump(indent + 6);
                    }
                }
            },
        };
    }
};

const Statement = union(enum) {
    constantDeclaration: ConstantDeclaration,
    returnStatement: ReturnStatement,
};

pub fn main() !void {
    const n1 = Literal{ .value = 2 };
    const n2 = Literal{ .value = 23 };
    const n1Exp = Expression{ .literal = n1 };
    const n2Exp = Expression{ .literal = n2 };
    const variable_expression = Expression{ .variable = Variable{ .name = "abc" } };
    const b = Expression{ .binaryExpression = BinaryExpression{ .opr = .Multiply, .lhs = &variable_expression, .rhs = &n2Exp } };

    const statements = [_]Statement{
        Statement{ .constantDeclaration = ConstantDeclaration{ .constantName = "abc", .expression = &n1Exp } },
        Statement{ .returnStatement = ReturnStatement{ .expression = &b } },
    };
    const block = Block{ .statements = &statements };

    const bE = Expression{ .block = block };

    const allocator = std.heap.page_allocator;
    var scope = std.StringHashMap(i32).init(allocator);
    const context = Context.init(&scope);

    const result = bE.evaluate(context);

    try bE.dump(0);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {d}!\n", .{result});
}

const Color = enum {
    auto,
    off,
    on,
};

test "enum literals with switch" {
    const color = Color.off;
    const result = switch (color) {
        .auto => false,
        .on => false,
        .off => true,
    };
    try expect(result);
}
