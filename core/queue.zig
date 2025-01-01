const std = @import("std");

pub const Queue = struct {
    items: std.ArrayList([]u8),

    mutex: std.Thread.Mutex,

    pub fn init(items: std.ArrayList([]u8)) Queue {
        return .{
            .items = items,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Queue) void {
        self.items.deinit();
    }

    pub fn getItems(self: *Queue) ![][]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.items.toOwnedSlice();
    }

    pub fn addItems(self: *Queue, items: []const []u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.items.appendSlice(items);
    }
};
