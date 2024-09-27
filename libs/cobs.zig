const std = @import("std");

pub const Error = COBSError || COBSLenError;

pub const COBSError = error{
    ZeroByteNotFound,
    OverheadByteOutOfBounds,
    PayloadTooLong,
};

pub const COBSLenError = error{
    PayloadTooShort,
    PayloadTooLong,
};

// COBS encodeing wiht length of original message
pub fn encode_len(source: []u8, dest: []u8) Error![]u8 {
    // 256 - (payload length) - (overhead byte) - (zero byte) 
    if (source.len > 253) {
        return COBSLenError.PayloadTooLong;
    }
    dest[0] = @as(u8, @intCast(source.len));
    dest[source.len + 2] = 0;

    var distance: u8 = 0;
    var i = source.len;
    for (source) |_| {
        i -= 1;

        distance += 1;
        if (source[i] == 0) {
            dest[i + 2] = distance;
            distance = 0;
            continue;
        }

        dest[i + 2] = source[i];

        if (i == 0)  break;
    }

    dest[1] = distance + 1;

    return dest[0..source.len+3];
}

// COBS (Consistent Overhead Byte Stuffing) + prefix length byte
pub fn decode_len(reader: std.io.AnyReader, buf: []u8) anyerror![]u8 {
    // read first by which should be prefix with length of payload
    // if there is nothing to read - then message is empty
    const prefix_payload_length: u8 = reader.readByte() catch |err| switch (err) {
        error.EndOfStream => {
            return buf[0..0];
        },
        else => {
            return err;
        },
    };

    const decoded_message = try decode(reader, buf);

    const actual_payload_length = decoded_message.len;
    if (prefix_payload_length < actual_payload_length) return COBSLenError.PayloadTooLong;
    if (prefix_payload_length > actual_payload_length) return COBSLenError.PayloadTooShort;

    return buf[0..prefix_payload_length];
}

fn decode(reader: std.io.AnyReader, buf: []u8) anyerror![]u8 {
    var next_zero_index: usize = 0;
    var found_zero_byte = false;

    // overhead byte is the position of next 00
    // in case there is nothing to read, check for special case with 0 value prefix
    const overhead_byte: u8 = reader.readByte() catch |err| switch (err) {
        error.EndOfStream => {
            return buf[0..0];
        },
        else => {
            return err;
        },
    };

    if (overhead_byte == 0) {
        return buf[0..0];
    }

    next_zero_index = overhead_byte;

    var i: usize = 0;
    var j: usize = 0; // result buffer index
    for (0..255) |_| {
        i += 1;
        j = i - 1;
        const byte: u8 = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => {
                break;
            },
            else => {
                return err;
            },
        };

        if (byte == 0) {
            if (i != next_zero_index) {
                return COBSError.OverheadByteOutOfBounds;
            }

            found_zero_byte = true;
            break;
        }

        if (i == next_zero_index) {
            buf[j] = 0;
            next_zero_index = i + @as(usize, @intCast(byte));
            continue;
        }

        buf[j] = byte;
    }

    if (!found_zero_byte) return COBSError.ZeroByteNotFound;
    return buf[0..j];
}

test "encode_len" {
    std.debug.print("bytes with one zero\n", .{});
    var source1 = [_]u8{0, 1, 3, 5};
    var dest: [256]u8 = undefined;

    const res1 = try encode_len(&source1, &dest);
    try std.testing.expectEqual(7, res1.len);
    try std.testing.expectEqual(4, res1[0]);
    try std.testing.expectEqual(0, res1[6]);
    try std.testing.expectEqual(1, res1[1]);

    std.debug.print("no zeroes\n", .{});
    var source2 = [_]u8{8, 1, 3, 5, 8};
    dest = undefined;

    const res2 = try encode_len(&source2, &dest);
    try std.testing.expectEqual(8, res2.len);
    try std.testing.expectEqual(5, res2[0]);
    try std.testing.expectEqual(8, res2[6]);
    try std.testing.expectEqual(0, res2[7]);
    try std.testing.expectEqual(6, res2[1]);

    std.debug.print("2 zeroes\n", .{});
    var source3 = [_]u8{8, 0, 3, 5, 0};
    dest = undefined;

    const res3 = try encode_len(&source3, &dest);
    try std.testing.expectEqual(8, res3.len);
    try std.testing.expectEqual(5, res3[0]);
    try std.testing.expectEqual(2, res3[1]);
    try std.testing.expectEqual(3, res3[3]);
    try std.testing.expectEqual(1, res3[6]);
    try std.testing.expectEqual(0, res3[7]);
}

test "decode" {
    std.debug.print("{s}\n", .{"empty input buffer"});
    var buffer_input_0 = [_]u8{};
    var buffer: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer_input_0);
    var reader = stream.reader().any();

    var res_bytes = try decode(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"buffer with only 0 as length prefix"});
    var buffer_input_1 = [_]u8{0};
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_1);
    reader = stream.reader().any();

    res_bytes = try decode(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"buffer with only 0 as length prefix, and termination byte"});
    var buffer_input_2 = [_]u8{ 0, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_2);
    reader = stream.reader().any();

    res_bytes = try decode(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"overhead byte past pass the max bound"});
    var buffer_input_3 = [_]u8{ 255, 2, 5, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_3);
    reader = stream.reader().any();

    var res = decode(reader, &buffer);
    try std.testing.expectEqual(COBSError.OverheadByteOutOfBounds, res);

    std.debug.print("{s}\n", .{"next zero bytes points to out of array"});
    var buffer_input_4 = [_]u8{ 2, 2, 5, 2, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_4);
    reader = stream.reader().any();

    res = decode(reader, &buffer);
    try std.testing.expectEqual(COBSError.OverheadByteOutOfBounds, res);

    std.debug.print("{s}\n", .{"valid message"});
    var buffer_input_6 = [_]u8{ 1, 3, 6, 6, 4, 6, 6, 6, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_6);
    reader = stream.reader().any();

    res_bytes = try decode(reader, &buffer);
    try std.testing.expectEqual(7, res_bytes.len);

    std.debug.print("{s}\n", .{"valid message without payload"});
    var buffer_input_7 = [_]u8{ 1, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_7);
    reader = stream.reader().any();

    res_bytes = try decode(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);
}

test "decode_len" {
    std.debug.print("{s}\n", .{"empty input buffer"});
    var buffer_input_0 = [_]u8{};
    var buffer: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer_input_0);
    var reader = stream.reader().any();

    var res_bytes = try decode_len(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"buffer with only 0 as length prefix"});
    var buffer_input_1 = [_]u8{0};
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_1);
    reader = stream.reader().any();

    res_bytes = try decode_len(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"buffer with only 0 as length prefix"});
    var buffer_input_2 = [_]u8{ 0, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_2);
    reader = stream.reader().any();

    res_bytes = try decode_len(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"buffer with only 0 as length prefix"});
    var buffer_input_3 = [_]u8{ 0, 1, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_3);
    reader = stream.reader().any();

    res_bytes = try decode_len(reader, &buffer);
    try std.testing.expectEqual(0, res_bytes.len);

    std.debug.print("{s}\n", .{"valid message"});
    var buffer_input_5 = [_]u8{ 1, 1, 1, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_5);
    reader = stream.reader().any();

    res_bytes = try decode_len(reader, &buffer);
    try std.testing.expectEqual(1, res_bytes.len);

    std.debug.print("{s}\n", .{"message too short"});
    var buffer_input_6 = [_]u8{ 9, 1, 1, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_6);
    reader = stream.reader().any();

    var res = decode_len(reader, &buffer);
    try std.testing.expectEqual(COBSLenError.PayloadTooShort, res);

    std.debug.print("{s}\n", .{"message too long "});
    var buffer_input_7 = [_]u8{ 1, 1, 2, 6, 0 };
    buffer = undefined;
    stream = std.io.fixedBufferStream(&buffer_input_7);
    reader = stream.reader().any();

    res = decode_len(reader, &buffer);
    try std.testing.expectEqual(COBSLenError.PayloadTooLong, res);
}
