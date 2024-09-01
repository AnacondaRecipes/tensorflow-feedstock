package(default_visibility = ["//visibility:public"])

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "cc_wrapper",
    srcs = [
        "cc_wrapper.sh",
        "cc_wrapper_build.sh",
    ],
)

filegroup(
    name = "compiler_deps",
    srcs = [":cc_wrapper"],
)

load(
    ":cc_toolchain_config.bzl", "cc_toolchain_config"
    )

cc_toolchain_config(
    name = "cc-compiler-target-config"
)

load(
    ":cc_toolchain_build_config.bzl", build_cc_toolchain_config = "cc_toolchain_config"
)
build_cc_toolchain_config(
    name = "cc-compiler-build-config"
)

toolchains = {
    "BUILD_CPU|compiler": ":cc-compiler-build",
    "BUILD_CPU": ":cc-compiler-build",
}
toolchains["TARGET_CPU|compiler"] = ":cc-compiler-target"
toolchains["TARGET_CPU"] = ":cc-compiler-target"
cc_toolchain_suite(
    name = "toolchain",
    toolchains = toolchains,
)

cc_toolchain(
    name = "cc-compiler-target",
    all_files = ":compiler_deps",
    compiler_files = ":compiler_deps",
    toolchain_identifier = "local",
    toolchain_config = ":cc-compiler-target-config",
    dwp_files = ":empty",
    linker_files = ":compiler_deps",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 0,
)

cc_toolchain(
    name = "cc-compiler-build",
    all_files = ":compiler_deps",
    compiler_files = ":compiler_deps",
    toolchain_identifier = "build",
    toolchain_config = ":cc-compiler-build-config",
    dwp_files = ":empty",
    linker_files = ":compiler_deps",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 0,
)

toolchain(
    name = "cc_cf_toolchain",
    toolchain = ":cc-compiler-target",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    exec_compatible_with = [
        "@platforms//cpu:BUILD_PLATFORM_CPU",
        "@platforms//os:BUILD_PLATFORM_OS",
    ],
    target_compatible_with = [
        "@platforms//cpu:TARGET_PLATFORM_CPU",
        "@platforms//os:TARGET_PLATFORM_OS",
    ],
)

toolchain(
    name = "cc_cf_host_toolchain",
    toolchain = ":cc-compiler-build",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    exec_compatible_with = [
        "@platforms//cpu:BUILD_PLATFORM_CPU",
        "@platforms//os:BUILD_PLATFORM_OS",
    ],
    target_compatible_with = [
        "@platforms//cpu:BUILD_PLATFORM_CPU",
        "@platforms//os:BUILD_PLATFORM_OS",
    ],
)

platform(
    name = "build_platform",
    constraint_values = [
        "@platforms//os:BUILD_PLATFORM_OS",
        "@platforms//cpu:BUILD_PLATFORM_CPU",
    ],
)

platform(
    name = "target_platform",
    constraint_values = [
        "@platforms//os:TARGET_PLATFORM_OS",
        "@platforms//cpu:TARGET_PLATFORM_CPU",
    ],
)
