{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  copyDesktopItems,
  makeWrapper,
  ffmpeg-headless,
  yt-dlp,
  makeDesktopItem,
  electron,
}:

buildNpmPackage rec {
  pname = "ytDownloader";
  version = "3.19.0";

  src = fetchFromGitHub {
    owner = "aandrew-me";
    repo = "ytDownloader";
    tag = "v${version}";
    hash = "sha256-Oj462x1oyhaLFbVNr90hKmg0S+BZXUv1DyNdxsc2L7Y=";
  };

  npmDepsHash = "sha256-ZJdPfNndYOWzvJpgra16/tCuWTvPLd4ZhSFualJB00E=";

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
  ];
  buildInputs = [
    ffmpeg-headless
    yt-dlp
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "ytDownloader";
      exec = "ytdownloader %U";
      icon = "ytdownloader";
      desktopName = "ytDownloader";
      comment = "A modern GUI video and audio downloader";
      categories = [ "Utility" ];
      startupWMClass = "ytDownloader";
    })
  ];

  ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  dontNpmBuild = true;

  # Patch config dir to ~/.config/ytdownloader
  # Otherwise it stores config in ~/.config/Electron
  patches = [ ./config-dir.patch ];

  # Replace hardcoded ffmpeg and ytdlp paths
  # Also stop it from downloading ytdlp
  postPatch = ''
    substituteInPlace src/renderer.js \
      --replace-fail $\{__dirname}/../ffmpeg '${lib.getExe ffmpeg-headless}' \
      --replace-fail 'path.join(os.homedir(), ".ytDownloader", "ytdlp")' '`${lib.getExe yt-dlp}`' \
      --replace-fail '!!localStorage.getItem("fullYtdlpBinPresent")' 'true'
    # Disable auto-updates
    substituteInPlace src/preferences.js \
      --replace-warn 'const autoUpdateDisabled = getId("autoUpdateDisabled");' 'const autoUpdateDisabled = "true";'
  '';

  postInstall = ''
    makeWrapper ${electron}/bin/electron $out/bin/ytdownloader \
        --add-flags $out/lib/node_modules/ytdownloader/main.js \
        --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]}

    install -Dm444 assets/images/icon.png $out/share/pixmaps/ytdownloader.png
  '';

  meta = {
    description = "Modern GUI video and audio downloader";
    homepage = "https://github.com/aandrew-me/ytDownloader";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ chewblacka ];
    platforms = lib.platforms.all;
    mainProgram = "ytdownloader";
  };
}
