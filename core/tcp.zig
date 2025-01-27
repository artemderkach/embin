const std = @import("std");

const xev = @import("xev");

const net = std.net;
const posix = std.posix;
const mem = std.mem;

const allocator = std.testing.allocator;

pub const TCP = struct {
    loop: *xev.Loop,
    allocator: std.mem.Allocator,
    address: net.Address,
    server: *ServerState,
    socket: posix.socket_t = undefined,

    pub fn listen(self: *TCP) !void {
        std.debug.print("hello\n", .{});
        std.debug.print("addr: {any}\n", .{self.address});

        const socket = try posix.socket(self.address.any.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
        errdefer posix.close(socket);

        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
        try posix.bind(socket, &self.address.any, self.address.getOsSockLen());
        try posix.listen(socket, 1);

        var c_accept: xev.Completion = .{
            .op = .{ .accept = .{ .socket = socket } },
            .userdata = self.server,
            .callback = acceptCallback,
        };

        self.loop.add(&c_accept);

        try self.loop.run(.until_done);
        std.debug.print("added to the loop\n", .{});
        // Accept
        // Run the loop until there are no more completions.
    }
};

test "TCP" {
    var loop = try xev.Loop.init(.{});
    defer loop.deinit();

    var state = ServerState{
        .connections = ConnMap.init(allocator),
        .allocator = allocator,
    };

    const addr = try net.Address.parseIp("127.0.0.1", 8080);

    var tcp = TCP{
        .loop = &loop,
        .address = addr,
        .allocator = allocator,
        .server = &state,
    };
    // _ = &tcp;

    std.debug.print("hello {any}\n", .{"123"});
    try std.testing.expect(true);
    // try std.testing.expect(false);
    //
    //

    std.debug.print("started loop {any}\n", .{"123"});

    try tcp.listen();

    std.debug.print("ended loop {any}\n", .{"123"});
    // try tcp.listen();
}

const ServerState = struct {
    connections: ConnMap,
    allocator: mem.Allocator,

    pub fn remove(self: *ServerState, fd: posix.socket_t) void {
        var pair = self.connections.fetchRemove(fd).?;
        pair.value.deinit();
    }
};

const ConnMap = std.AutoHashMap(posix.socket_t, *Connection);
// const CompMap = std.AutoHashMap(usize, *Completion);

const Completion = struct {
    id: usize,
    comp: xev.Completion,
};

const Connection = struct {
    fd: posix.socket_t,
    buf: [512]u8,
    // comp: CompMap,
    write_len: usize = 0,

    server_state: *ServerState,

    pub fn init(server_state: *ServerState, new_fd: posix.socket_t) *Connection {
        var conn = server_state.allocator.create(Connection) catch unreachable;
        conn.fd = new_fd;
        conn.server_state = server_state;
        // conn.comp = CompMap.init(server_state.allocator);
        return conn;
    }

    pub fn deinit(self: *Connection) void {
        self.server_state.allocator.destroy(self);
    }

    pub fn read_buf(self: *Connection) []u8 {
        return self.buf[0..256];
    }
    pub fn write_buf(self: *Connection) []u8 {
        return self.buf[256..512];
    }

    // pub fn read(self: *Connection, loop: *xev.Loop) !void {
    //     var c = xev.Completion{
    //         .op = .{
    //             .recv = .{
    //                 .fd = self.fd,
    //                 .buffer = .{ .slice = self.read_buf() },
    //             },
    //         },
    //         .userdata = self,
    //         .callback = recvCallback,
    //     };
    //     var comp = Completion{
    //         .comp = c,
    //         .id = 1,
    //     };
    //
    //     try self.comp.put(comp.id, &comp);
    //
    //     loop.add(&c);
    // }
    //
    // pub fn write(self: *Connection, loop: *xev.Loop, buf: []u8) !void {
    //     var c = xev.Completion{
    //         .op = .{
    //             .send = .{
    //                 .fd = self.fd,
    //                 .buffer = .{ .slice = buf },
    //             },
    //         },
    //         .userdata = self,
    //         .callback = sendCallback,
    //     };
    //     var comp = Completion{
    //         .comp = c,
    //         .id = 2,
    //     };
    //
    //     try self.comp.put(comp.id, &comp);
    //
    //     loop.add(&c);
    // }
    //
    // pub fn close(self: *Connection, loop: *xev.Loop) void {
    //     var comp = xev.Completion{
    //         .op = .{ .close = .{ .fd = self.fd } },
    //         .userdata = self,
    //         .callback = closeCallback,
    //     };
    //
    //     loop.add(&comp);
    // }
};

fn acceptCallback(ud: ?*anyopaque, _: *xev.Loop, _: *xev.Completion, result: xev.Result) xev.CallbackAction {
    // std.log.info("Completion: {any}, result: {any}\n", .{ comp, result });
    std.log.info("1\n", .{});

    const new_fd = result.accept catch unreachable;
    var state = @as(*ServerState, @ptrCast(@alignCast(ud.?)));
    std.log.info("1\n", .{});
    const new_conn = Connection.init(state, new_fd);
    std.log.info("2\n", .{});

    state.connections.put(new_fd, new_conn) catch unreachable;
    std.log.info("4\n", .{});
    return .disarm;
}

// fn recvCallback(ud: ?*anyopaque, loop: *xev.Loop, comp: *xev.Completion, result: xev.Result) xev.CallbackAction {
//     std.log.info("Completion: {}, result: {any}", .{ comp.flags.state, result });
//
//     const recv = comp.op.recv;
//     const conn = @as(*Connection, @ptrCast(@alignCast(ud.?)));
//     const read_len = result.recv catch {
//         conn.close(loop);
//         return .disarm;
//     };
//     std.log.info(
//         "Recv from {} ({} bytes): {s}",
//         .{ recv.fd, read_len, recv.buffer.slice[0..read_len] },
//     );
//     conn.write(loop, recv.buffer.slice[0..read_len]) catch unreachable;
//     return .disarm;
// }

// fn sendCallback(ud: ?*anyopaque, loop: *xev.Loop, comp: *xev.Completion, result: xev.Result) xev.CallbackAction {
//     std.log.info("Completion: {}, result: {any}", .{ comp.flags.state, result });
//
//     const send = comp.op.send;
//     const conn = @as(*Connection, @ptrCast(@alignCast(ud.?)));
//     const send_len = result.send catch {
//         conn.close(loop);
//         return .disarm;
//     };
//     std.log.info(
//         "Send   to {} ({} bytes): {s}",
//         .{ send.fd, send_len, send.buffer.slice[0..send_len] },
//     );
//
//     conn.write_len += send_len;
//     if (conn.write_len >= send.buffer.slice.len) {
//         conn.read(loop) catch unreachable;
//         conn.write_len = 0;
//         return .disarm;
//     }
//     return .rearm;
// }
//
// fn closeCallback(ud: ?*anyopaque, _: *xev.Loop, comp: *xev.Completion, result: xev.Result) xev.CallbackAction {
//     std.log.info("Completion: {}, result: {any}", .{ comp.flags.state, result });
//     const conn = @as(*Connection, @ptrCast(@alignCast(ud.?)));
//     conn.server_state.remove(comp.op.close.fd);
//     return .disarm;
// }

