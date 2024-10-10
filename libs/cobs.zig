/// COBS (Consisten Overhead Byte Stuffing)
/// data -                [12, 44, 00, 04, 00, 00, 01]
/// encoded data -    [03, 12, 44, 02, 04, 01, 02, 01]
/// packetized data - [03, 12, 44, 02, 04, 01, 02, 01, 00]
/// encoding puts index of next zero instead of zero
/// packetizing adds zero at the end
///
/// this lib exposes 2 functions 'cobs' and 'cobs_short'
/// 'cobs' encode message with any length, this will also have
/// uncertainty about the length of resulting message
/// 'cobs_short' will handle only messages with 'source_max_len' (254) length
/// it limits the type of message you can pass but adds certainty about the
/// maximum length of message
/// it also can be decoded with same function as default 'cobs'
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

// pub const Error = COBSError || COBSLenError;

pub const Error = error{
    ZeroByteNotFound,
    OverheadByteOutOfBounds,
    PayloadTooLong,
    PayloadCannotBeEmpty,
    SourceCannotBeZero,
    DestinationTooShort,

    PayloadTooShort,
    // PayloadTooLong,
};

pub const source_max_len = 254;

/// max diff is 255 becouse it is max number that can be
/// represented by u8
pub const max_diff = 255;

/// finds maximum possible destination length
/// needed to create slice that will be passed to 'cobs' function
/// at least it needs +2 for overhead byte and zero byte at the end
/// also we require additional additional +1 on every 255 bytes (at max)
pub fn get_max_dest_len(source: []u8) usize {
    return source.len + 2 + @as(usize, source.len / 255);
}

pub fn encode(source: []u8, dest: []u8) Error![]u8 {
    if (dest.len < get_max_dest_len(source)) {
        return Error.DestinationTooShort;
    }
    const res = encode_short(source, dest) catch |err| switch (err) {
        Error.PayloadTooLong => return encode_long(source, dest),
        else => return err,
    };

    return res;
}

/// encode short slice of bytes (<= 254)
/// this function is needed because encoding short messages
/// require less logic is more efficient
/// 256 - overhead byte - zero byte
/// [overhead byte, data, zero byte]
/// returned slice is the
pub fn encode_short(source: []u8, dest: []u8) Error![]u8 {
    if (source.len > source_max_len) {
        return Error.PayloadTooLong;
    }

    // 2 for overhead byte and zero byte
    const new_dest_len = source.len + 2;
    if (dest.len < new_dest_len) {
        return Error.DestinationTooShort;
    }

    // source iterator
    var i = source.len;
    // destination iterator
    var j = source.len + 1;

    // last byte of destination
    dest[j] = 0;

    // iterate over source backwards
    var last_zero_position = j;
    for (source) |_| {
        i -= 1;
        j -= 1;

        if (source[i] == 0) {
            // range between zero bytes
            const diff = last_zero_position - j;

            last_zero_position = j;
            dest[j] = @as(u8, @intCast(diff));
            continue;
        }

        dest[j] = source[i];
    }
    dest[0] = @as(u8, @intCast(last_zero_position));

    return dest[0..new_dest_len];
}

/// encodes message without the limit and without the check for short message
/// this is more of a classic approach for handling cobs
/// but giving that encode is already taken, this will get _long name
pub fn encode_long(source: []u8, dest: []u8) Error![]u8 {
    const max_dest_len = get_max_dest_len(source);
    if (dest.len < max_dest_len) {
        return Error.DestinationTooShort;
    }

    var zero_pos: usize = 0;
    // destination iterator
    var j: usize = 0;
    for (source, 0..) |_, i| {
        // destination is always one ahead because of overhead byte
        j += 1;

        if (j - zero_pos == max_diff) {
            dest[zero_pos] = max_diff;
            zero_pos = j;
            j += 1;
        }

        if (source[i] == 0) {
            dest[zero_pos] = @as(u8, @intCast(j - zero_pos));
            zero_pos = j;
            continue;
        }

        dest[j] = source[i];
    }

    j += 1;
    dest[j] = 0;
    dest[zero_pos] = @as(u8, @intCast(j - zero_pos));

    return dest[0 .. j + 1];
}

pub fn decode(source: []u8, dest: []u8) Error![]u8 {
    if (source.len < 2) {
        return Error.PayloadTooShort;
    }

    var j: usize = 0; // destination iterator
    var i: usize = 1; // skip overhead byte
    var next_zero: usize = source[0]; // overhead byte

    for (1..source.len - 1) |_| {
        if (i == next_zero) {
            if (i - next_zero != 0xFF) {
                dest[j] = 0;
                j += 1;
            }

            next_zero = i + source[i];
            i += 1;
            continue;
        }

        dest[j] = source[i];
        j += 1;
        i += 1;
    }

    return dest[0..j];
}

test "get_max_dest_len" {
    // 0 length input
    var arr = [_]u8{};
    var len = get_max_dest_len(&arr);
    try std.testing.expectEqual(2, len);

    // non-zero but less the 255
    var arr2: [100]u8 = undefined;
    len = get_max_dest_len(&arr2);
    try std.testing.expectEqual(102, len);

    // max length 254
    var arr3: [254]u8 = undefined;
    len = get_max_dest_len(&arr3);
    try std.testing.expectEqual(256, len);

    // 255
    var arr4: [255]u8 = undefined;
    len = get_max_dest_len(&arr4);
    try std.testing.expectEqual(258, len);

    // 1000
    var arr5: [1000]u8 = undefined;
    len = get_max_dest_len(&arr5);
    try std.testing.expectEqual(1005, len);
}

test "encode_short" {
    {
        // empty input
        const source = [_]u8{};
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 1, 0 }, res);
    }
    {
        // empty output
        var source: [100]u8 = undefined;
        var dest = [_]u8{};
        const res = encode_short(&source, &dest);
        try expectEqual(Error.DestinationTooShort, res);
    }
    {
        // destination just a bit shorter that it need to be
        var source: [100]u8 = undefined;
        var dest: [101]u8 = undefined;
        const res = encode_short(&source, &dest);
        try expectEqual(Error.DestinationTooShort, res);
    }
    {
        // source just above allowed value
        var source: [255]u8 = undefined;
        var dest: [256]u8 = undefined;
        const res = encode_short(&source, &dest);
        try expectEqual(Error.PayloadTooLong, res);
    }
    {
        // source too huge
        var source: [1000]u8 = undefined;
        var dest: [256]u8 = undefined;
        const res = encode_short(&source, &dest);
        try expectEqual(Error.PayloadTooLong, res);
    }
    {
        // destination is just minimum needed amount
        var source: [100]u8 = undefined;
        var dest: [102]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqual(102, res.len);
    }
    {
        // destination length is far bigger then source
        var source: [100]u8 = undefined;
        var dest: [1000]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqual(102, res.len);
    }
    {
        // source is just at its limit
        var source: [254]u8 = undefined;
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqual(256, res.len);
    }
    {
        // simple case without any zero bytes
        var source = [_]u8{ 1, 2, 3, 4 };
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 5, 1, 2, 3, 4, 0 }, res);
    }
    {
        // simple case with single zero byte
        var source = [_]u8{ 1, 2, 0, 4, 5 };
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 3, 1, 2, 3, 4, 5, 0 }, res);
    }
    {
        // input with single zero byte
        var source = [_]u8{0};
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 1, 1, 0 }, res);
    }
    {
        var source = [_]u8{ 0, 0 };
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 1, 1, 1, 0 }, res);
    }
    {
        var source = [_]u8{ 0, 1, 0 };
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 1, 2, 1, 1, 0 }, res);
    }
    {
        // actual max size without zero bytes
        var source = [_]u8{1} ** 254;
        var dest: [256]u8 = undefined;
        const res = try encode_short(&source, &dest);
        var exp = [_]u8{1} ** 256;
        exp[0] = 0xFF;
        exp[0xFF] = 0;
        try expectEqualSlices(u8, &exp, res);
    }
}

test "encode_long" {
    {
        // small destination
        var source: [100]u8 = undefined;
        var dest: [0]u8 = undefined;
        const res = encode_long(&source, &dest);
        try expectEqual(Error.DestinationTooShort, res);
    }
    {
        // small destination but input is large
        var source: [800]u8 = undefined;
        var dest: [0]u8 = undefined;
        const res = encode_long(&source, &dest);
        try expectEqual(Error.DestinationTooShort, res);
    }
    {
        // try to encode some valid short message
        var source = [_]u8{ 1, 2, 3, 4, 5 };
        var dest: [10]u8 = undefined;
        const res = try encode_long(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 6, 1, 2, 3, 4, 5, 0 }, res);
    }
    {
        // try to encode some valid short message with some zero bytes
        var source = [_]u8{ 1, 0, 2, 3, 0, 4, 5 };
        var dest: [10]u8 = undefined;
        const res = try encode_long(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 2, 1, 3, 2, 3, 3, 4, 5, 0 }, res);
    }
    {
        // try to encode some valid short message with some zero bytes
        var source = [_]u8{1} ** 256;
        var dest: [300]u8 = undefined;
        const res = try encode_long(&source, &dest);

        var exp = [_]u8{1} ** 259;
        exp[0] = 0xFF;
        exp[255] = 3;
        exp[258] = 0;
        try expectEqualSlices(u8, &exp, res);
    }
    {
        // lot of data
        var source = [_]u8{1} ** 1000;
        source[200] = 0;
        source[400] = 0;
        var dest: [1100]u8 = undefined;
        const res = try encode_long(&source, &dest);

        var exp = [_]u8{1} ** 1004;
        exp[0] = 201;
        exp[201] = 200;
        exp[401] = 255;
        exp[656] = 255;
        exp[911] = 92;
        exp[1003] = 0;
        try expectEqual(exp[0], dest[0]);
        try expectEqual(exp[201], dest[201]);
        try expectEqual(exp[401], dest[401]);
        try expectEqual(exp[656], dest[656]);
        try expectEqual(exp[911], dest[911]);
        try expectEqualSlices(u8, &exp, res);
    }
}

test "decode" {
    {
        var source = [_]u8{ 3, 1, 2, 3, 4, 5, 0 };
        var dest: [256]u8 = undefined;
        const res = try decode(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 1, 2, 0, 4, 5 }, res);
    }
    {
        var source = [_]u8{ 7, 1, 2, 3, 4, 5, 6, 0 };
        var dest: [256]u8 = undefined;
        const res = try decode(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 5, 6 }, res);
    }
    {
        // all zero
        var source = [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0 };
        var dest: [256]u8 = undefined;
        const res = try decode(&source, &dest);
        try expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0, 0, 0 }, res);
    }
    {
        var source = [_]u8{1} ** 259;
        source[0] = 0xFF;
        source[255] = 3;
        source[258] = 0;
        var dest: [1000]u8 = undefined;
        const res = try decode(&source, &dest);

        const exp = [_]u8{1} ** 256;
        try expectEqual(exp.len, res.len);
        try expectEqual(exp[0], res[0]);
        try expectEqual(exp[1], res[1]);
        try expectEqual(exp[255], res[255]);
        try expectEqualSlices(u8, &exp, res);
    }
    {
        var source = [_]u8{1} ** 1000;
        source[0] = 0xFF;
        source[255] = 0xFF;
        source[510] = 0xFF;
        source[765] = 234;
        source[999] = 0;
        var dest: [1000]u8 = undefined;
        const res = try decode(&source, &dest);

        const exp = [_]u8{1} ** 997;
        try expectEqual(exp.len, res.len);
        try expectEqual(exp[0], res[0]);
        try expectEqual(exp[1], res[1]);
        try expectEqual(exp[255], res[255]);
        try expectEqual(exp[510], res[510]);
        try expectEqual(exp[764], res[764]);
        try expectEqual(exp[765], res[765]);
        try expectEqual(exp[766], res[766]);
        try expectEqual(exp[996], res[996]);
        try expectEqualSlices(u8, &exp, res);
    }
}
