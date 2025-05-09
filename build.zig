const std = @import("std");

fn libMachineFromTarget(arch: std.Target.Cpu.Arch) []const u8 {
    return switch (arch) {
        .x86_64 => "x64",
        else => |a| std.debug.panic("translate arch '{s}' to /machine:?", .{@tagName(a)}),
    };
}

fn addCMacros(module: *std.Build.Module) void {
    module.addCMacro("UNICODE", "1");
    module.addCMacro("_UNICODE", "1");
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const usp_lib = b.addStaticLibrary(.{
        .name = "usp",
        .target = target,
        .optimize = optimize,
    });
    addCMacros(usp_lib.root_module);
    usp_lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "UspLib/UspCtrl.c",
            "UspLib/UspLib.c",
            "UspLib/UspMouse.c",
            "UspLib/UspPaint.c",
        },
    });
    usp_lib.linkLibC();

    const textview_lib = b.addStaticLibrary(.{
        .name = "textview",
        .target = target,
        .optimize = optimize,
    });
    addCMacros(textview_lib.root_module);
    textview_lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "TextView/sequence.cpp",
            "TextView/TextDocument.cpp",
            "TextView/TextView.cpp",
            "TextView/TextViewClipboard.cpp",
            "TextView/TextViewFile.cpp",
            "TextView/TextViewFont.cpp",
            "TextView/TextViewKeyInput.cpp",
            "TextView/TextViewKeyNav.cpp",
            "TextView/TextViewMouse.cpp",
            "TextView/TextViewPaint.cpp",
            "TextView/TextViewScroll.cpp",
        },
        .flags = &[_][]const u8{
            "-std=c++17",
        },
    });
    textview_lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "TextView/Unicode.c",
        },
    });
    textview_lib.linkLibCpp();
    textview_lib.linkLibrary(usp_lib);
    textview_lib.linkSystemLibrary("uxtheme");

    // zig's mingw seems to be missing the .lib file
    const scrnsave_lib = blk: {
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "lib",
            b.fmt("/machine:{s}", .{libMachineFromTarget(target.result.cpu.arch)}),
        });
        run.addPrefixedFileArg("/def:", b.path("scrnsave.def"));
        break :blk run.addPrefixedOutputFileArg("/out:", "scrnsave.lib");
    };

    // zig lib /def:scrnsave.def /out:scrnsave.lib /machine:x64

    // // We will also create a module for our other entry point, 'main.zig'.
    // const exe_mod = b.createModule(.{
    //     // `root_source_file` is the Zig "entry point" of the module. If a module
    //     // only contains e.g. external object files, you can make this `null`.
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    const exe = b.addExecutable(.{
        .name = "neatpad",
        // .root_module = b.createModule(.{
        //     .target = target,
        //     .optimize = optimize,
        // }),
        .target = target,
        .optimize = optimize,
    });
    addCMacros(exe.root_module);
    exe.addCSourceFiles(.{
        .files = &[_][]const u8{
            "Neatpad/Neatpad.c",
            "Neatpad/NeatUtils.c",
            "Neatpad/OpenSave.c",
            "Neatpad/Options.c",
            "Neatpad/OptionsDisplay.c",
            "Neatpad/OptionsFont.c",
            "Neatpad/OptionsMisc.c",
            "Neatpad/Printing.c",
            "Neatpad/Search.c",
            "Neatpad/Toolbars.c",
        },
    });

    exe.linkLibrary(textview_lib);
    exe.addObjectFile(scrnsave_lib);
    exe.linkLibC();
    exe.linkSystemLibrary("comctl32");
    exe.linkSystemLibrary("comdlg32");
    exe.linkSystemLibrary("gdi32");
    //exe.linkSystemLibrary("Scrnsave");
    exe.linkSystemLibrary("ole32");
    // exe.linkSystemLibrary("user32");
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run.step);
}
