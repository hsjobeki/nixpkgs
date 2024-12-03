{
  lib,
  stdenv,

  fetchFromGitHub,

  cmake,
  ninja,
  pkg-config,
  removeReferencesTo,

  double-conversion,
  fast-float,
  gflags,
  glog,
  libevent,
  zlib,
  openssl,
  xz,
  lz4,
  zstd,
  libiberty,
  libunwind,
  apple-sdk_11,
  darwinMinVersionHook,

  boost,
  fmt_11,
  jemalloc,

  follyMobile ? false,

  # for passthru.tests
  python3,
  watchman,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "folly";
  version = "2024.11.18.00";

  # split outputs to reduce downstream closure sizes
  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "facebook";
    repo = "folly";
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-CX4YzNs64yeq/nDDaYfD5y8GKrxBueW4y275edPoS0c=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    removeReferencesTo
  ];

  # See CMake/folly-deps.cmake in the Folly source tree.
  buildInputs =
    [
      boost
      double-conversion
      fast-float
      gflags
      glog
      libevent
      zlib
      openssl
      xz
      lz4
      zstd
      libiberty
      libunwind
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      apple-sdk_11
      (darwinMinVersionHook "11.0")
    ];

  propagatedBuildInputs =
    [
      # `folly-config.cmake` pulls these in.
      boost
      fmt_11
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      # jemalloc headers are required in include/folly/portability/Malloc.h
      jemalloc
    ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!stdenv.hostPlatform.isStatic))

    # Folly uses these instead of the standard CMake variables for some reason.
    (lib.cmakeFeature "INCLUDE_INSTALL_DIR" "${placeholder "dev"}/include")
    (lib.cmakeFeature "LIB_INSTALL_DIR" "${placeholder "out"}/lib")
    (lib.cmakeFeature "CMAKE_INSTALL_DIR" "${placeholder "dev"}/lib/cmake/folly")
    (lib.cmakeFeature "CMAKE_INSTALL_PREFIX" (placeholder "dev"))
  ];

  env.NIX_CFLAGS_COMPILE = lib.concatStringsSep " " (
    [
      "-DFOLLY_MOBILE=${if follyMobile then "1" else "0"}"
    ]
    ++ lib.optionals (stdenv.cc.isGNU && stdenv.hostPlatform.isAarch64) [
      # /build/source/folly/algorithm/simd/Movemask.h:156:32: error: cannot convert '__Uint64x1_t' to '__Uint8x8_t'
      "-flax-vector-conversions"
    ]
  );

  # https://github.com/NixOS/nixpkgs/issues/144170
  postPatch = ''
    substituteInPlace CMake/libfolly.pc.in \
      --replace-fail \
        ${lib.escapeShellArg "\${exec_prefix}/@LIB_INSTALL_DIR@"} \
        '@CMAKE_INSTALL_FULL_LIBDIR@' \
      --replace-fail \
        ${lib.escapeShellArg "\${prefix}/@CMAKE_INSTALL_INCLUDEDIR@"} \
        '@CMAKE_INSTALL_FULL_INCLUDEDIR@'
  '';

  postFixup = ''
    # Sanitize header paths to avoid runtime dependencies leaking in
    # through `__FILE__`.
    (
      shopt -s globstar
      for header in "$dev/include"/**/*.h; do
        sed -i "1i#line 1 \"$header\"" "$header"
        remove-references-to -t "$dev" "$header"
      done
    )
  '';

  passthru = {
    inherit boost;
    fmt = fmt_11;

    tests = {
      inherit watchman;
      inherit (python3.pkgs) django pywatchman;
    };
  };

  meta = {
    description = "Open-source C++ library developed and used at Facebook";
    homepage = "https://github.com/facebook/folly";
    license = lib.licenses.asl20;
    # 32bit is not supported: https://github.com/facebook/folly/issues/103
    platforms = lib.platforms.unix;
    badPlatforms = [ lib.systems.inspect.patterns.is32bit ];
    maintainers = with lib.maintainers; [
      abbradar
      pierreis
    ];
  };
})
