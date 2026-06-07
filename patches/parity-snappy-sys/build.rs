extern crate cmake;

use std::env;
use std::fs;

use cmake::Config;

fn main() {
	let src = env::current_dir().unwrap().join("snappy");

	// NOTE: the cfg! macro doesn't work when cross-compiling, it would return values for the host
	let target_os = env::var("CARGO_CFG_TARGET_OS").expect("CARGO_CFG_TARGET_OS is set by cargo.");
	let target_env = env::var("CARGO_CFG_TARGET_ENV").expect("CARGO_CFG_TARGET_ENV is set by cargo.");

	let mut cfg = Config::new("snappy");
	cfg.define("CMAKE_VERBOSE_MAKEFILE", "ON")
		.build_target("snappy");

	// snappy's CMakeLists does not pick an MSVC runtime, so cl.exe defaults to
	// the static runtime (/MT -> libcpmt.lib). Rust links the dynamic runtime
	// (/MD -> msvcprt.lib) by default, which causes LNK2005/LNK1169 duplicate
	// symbols at the final link. Force snappy to use the same runtime as Rust.
	if target_env.contains("msvc") {
		let features = env::var("CARGO_CFG_TARGET_FEATURE").unwrap_or_default();
		cfg.define("CMAKE_POLICY_DEFAULT_CMP0091", "NEW");
		if features.contains("crt-static") {
			cfg.define("CMAKE_MSVC_RUNTIME_LIBRARY", "MultiThreaded");
		} else {
			cfg.define("CMAKE_MSVC_RUNTIME_LIBRARY", "MultiThreadedDLL");
		}
	}

	let out = cfg.build();

	let mut build = out.join("build");

	if target_os.contains("windows") && target_env.contains("msvc") {
		let stub = build.join("snappy-stubs-public.h");

		let profile = match &*env::var("PROFILE").unwrap_or("debug".to_owned()) {
			"bench" | "release" => "Release",
			_ => "Debug",
		};
		build = build.join(profile);

		fs::copy(stub, build.join("snappy-stubs-public.h")).unwrap();
	}

	fs::copy(src.join("snappy.h"), build.join("snappy.h")).unwrap();

	println!("cargo:rustc-link-search=native={}", build.display());
	println!("cargo:rustc-link-lib=static=snappy");
	println!("cargo:include={}", build.display());

	// https://github.com/alexcrichton/cc-rs/blob/ca70fd32c10f8cea805700e944f3a8d1f97d96d4/src/lib.rs#L891
	if target_os.contains("macos") || target_os.contains("freebsd") || target_os.contains("openbsd") {
		println!("cargo:rustc-link-lib=c++");
	} else if !target_env.contains("msvc") && !target_os.contains("android") {
		println!("cargo:rustc-link-lib=stdc++");
	}
}
