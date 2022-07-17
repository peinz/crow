const std = @import("std");
const expect = std.testing.expect;

const ctx = @import("./context.zig");
const Context = ctx.Context;
const ast = @import("./ast.zig");

pub fn main() !void {
    const n1 = ast.Literal{ .value = 2 };
    const n2 = ast.Literal{ .value = 23 };
    const n1Exp = ast.Expression{ .literal = n1 };
    const n2Exp = ast.Expression{ .literal = n2 };
    const variable_expression = ast.Expression{ .variable = ast.Variable{ .name = "abc" } };
    const b = ast.Expression{ .binaryExpression = ast.BinaryExpression{ .opr = .Multiply, .lhs = &variable_expression, .rhs = &n2Exp } };

    const statements = [_]ast.Statement{
        ast.Statement{ .constantDeclaration = ast.ConstantDeclaration{ .constantName = "abc", .expression = &n1Exp } },
        ast.Statement{ .returnStatement = ast.ReturnStatement{ .expression = &b } },
    };
    const block = ast.Block{ .statements = &statements };

    const bE = ast.Expression{ .block = block };

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
