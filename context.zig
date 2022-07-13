const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Context = struct {
    allocator: ?*Allocator,
    scope: *std.StringHashMap(i32),
    parentScope: ?*Context,

    pub fn init(scope: *std.StringHashMap(i32)) Context {
        return Context{
            .allocator = null,
            .scope = scope,
            .parentScope = null,
        };
    }

    pub fn spawnNewScope(self: @This()) Context {
        var new_scope = std.StringHashMap(i32).init(self.allocator);
        return Context{
            .allocator = self.allocator,
            .scope = new_scope,
            .parentScope = &self,
        };
    }

    pub fn get(self: @This(), name: []const u8) i32 {
        // TODO: go through all scopes
        // TODO: throw error message if not found
        const value = self.scope.get(name);
        if (value) |v| {
            return v;
        }
        return 0;
    }

    pub fn set(self: @This(), name: []const u8, value: i32) void {
        // TODO: throw error message
        self.scope.put(name, value) catch unreachable;
    }
};
