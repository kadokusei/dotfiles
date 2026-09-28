{
  cmake,
  fetchFromGitHub,
  lib,
  libxkbcommon,
  openssl,
  pkg-config,
  rustPlatform,
  kdePackages,
  fcitx5,
}:
rustPlatform.buildRustPackage {
  pname = "karukan";
  version = "0.1.0-unstable-2026-09-26";

  src = fetchFromGitHub {
    owner = "togatoga";
    repo = "karukan";
    rev = "53775de1b9561269697112f0f3fc8b79783c368c";
    hash = "sha256-AeM60B38BHnNO5VPdqKG4YONVUJ6v8AH0mlsdbPCpJI=";
  };

  cargoHash = "sha256-2PKvzTYMenF8NtsKhP6qt/mMo0E6AgfD6WrZ1tfhQz4=";

  # ECM は buildInputs に置く: strictDeps ビルドでは CMAKE_PREFIX_PATH が
  # buildInputs 由来のパッケージからしか作られず、nativeBuildInputs の ECM が
  # find_package(ECM) で見つからない (nixpkgs の fcitx5 と同じ配置)
  nativeBuildInputs = [
    cmake
    pkg-config
    rustPlatform.bindgenHook # https://github.com/NixOS/nixpkgs/issues/52447#issuecomment-1915060425
    fcitx5
  ];

  buildInputs = [
    kdePackages.extra-cmake-modules
    fcitx5
    libxkbcommon
    openssl
  ];

  # target-cpu=native を無効化し CI でもビルドできる宣言的バイナリにする
  cmakeFlags = [ "-DKARUKAN_NATIVE=OFF" ];

  doCheck = false;

  # blog.anqou.net/2026/06/nixos-karukan/ の手法。repo 再構成後の addon パスは
  # karukan-im/fcitx5/fcitx5-addon (旧 karukan-im/fcitx5-addon は404)。
  # CMake が cargo を呼び、Rust cdylib (libkarukan_fcitx5.so) を fcitx5 モジュールに
  # in-process link して $out/lib/fcitx5, $out/share/fcitx5 へ install する
  configurePhase = ''
    runHook preConfigure
    pushd karukan-im/fcitx5/fcitx5-addon
    cmakeConfigurePhase
    popd
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    pushd karukan-im/fcitx5/fcitx5-addon
    cmake --build build
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    pushd karukan-im/fcitx5/fcitx5-addon
    cmake --install build
    popd
    runHook postInstall
  '';
}
