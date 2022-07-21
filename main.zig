const std = @import("std");
const expect = std.testing.expect;

const ctx = @import("./context.zig");
const Context = ctx.Context;
const ast = @import("./ast.zig");
const p = @import("./parser.zig");
const Parser = p.Parser;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // sytanx tree in code
    const n1 = ast.Literal{ .value = 2 };
    const n2 = ast.Literal{ .value = 23 };
    const n1Exp = ast.Expression{ .literal = n1 };
    const n2Exp = ast.Expression{ .literal = n2 };
    const variable_expression = ast.Expression{ .variable = ast.Variable{ .name = "abc" } };
    const b = ast.Expression{ .binaryExpression = ast.BinaryExpression{ .opr = .multiply, .lhs = &variable_expression, .rhs = &n2Exp } };

    var statements = [_]ast.Statement{
        ast.Statement{ .constantDeclaration = ast.ConstantDeclaration{ .constantName = "abc", .expression = &n1Exp } },
        ast.Statement{ .returnStatement = ast.ReturnStatement{ .expression = &b } },
    };
    var statement_list = std.ArrayList(ast.Statement).fromOwnedSlice(allocator, statements[0..]);
    const block = ast.Block{ .statements = statement_list };

    const bE = ast.Expression{ .block = block };

    var scope = std.StringHashMap(i32).init(allocator);
    const context = Context.init(&scope);
    const result = bE.evaluate(context);
    // try bE.dump(0);
    _ = result;

    // parse + dump
    const parser = try Parser.init(allocator);
    const parsed_ast = try parser.parse("program.tz");
    const exp = ast.Expression{ .block = parsed_ast };

    try exp.dump(0);

    const result2 = exp.evaluate(context);
    try stdout.print("result: {d}\n", .{result2});
}
