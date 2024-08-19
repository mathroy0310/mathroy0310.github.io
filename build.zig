const std = @import("std");
const zine = @import("zine");

pub fn build(b: *std.Build) !void {
        zine.website(b, .{
        .title = "Mathroy0310 blog",
        .host_url = "http:mathroy0310.github.io",
        .layouts_dir_path = "layouts",
        .content_dir_path = "content",
        .assets_dir_path = "assets",
        .static_assets = &.{
            "favicon.ico",
            "CNAME",
        },
        .debug = true,
    });
}