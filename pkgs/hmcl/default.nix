{ stdenv, lib, fetchFromGitHub, fetchurl, makeDesktopItem, copyDesktopItems
, makeWrapper, unzip, openjdk, gradle, perl, curl, libpulseaudio, systemd
, alsa-lib, flite, libXxf86vm }:

let
  name = "hmcl-${version}";
  version = "git-javafx";

  src = fetchFromGitHub rec {
    name = "github-${owner}-${repo}-${rev}";
    owner = "huanghongxun";
    repo = "HMCL";
    rev = "9b6b3f8938d77f5bc2508a09d6f0ca5228fc631f";
    sha256 = "17l288a74bs1zkvw9apzhgbajpl08zws6965saiwa223wzmlahfz";
  };

  gradlebinSrc = fetchurl {
    url = "https://services.gradle.org/distributions/gradle-7.0-bin.zip";
    sha256 = "eb8b89184261025b0430f5b2233701ff1377f96da1ef5e278af6ae8bac5cc305";
  };

  nativeBuildInputs = [ unzip openjdk copyDesktopItems makeWrapper ];

  # https://github.com/NixOS/nixpkgs/blob/8ecc61c91a596df7d3293603a9c2384190c1b89a/pkgs/games/minecraft/default.nix#L44
  envLibPath = lib.makeLibraryPath [
    curl
    libpulseaudio
    systemd
    alsa-lib # needed for narrator
    flite # needed for narrator
    libXxf86vm # needed only for versions <1.13
  ];

  deps = stdenv.mkDerivation {
    name = "${name}-deps";
    inherit version src gradlebinSrc;

    nativeBuildInputs = nativeBuildInputs ++ [ perl ];

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d)
      substituteInPlace gradle/wrapper/gradle-wrapper.properties --replace https\\://services.gradle.org/distributions/gradle-7.0-bin.zip file://${gradlebinSrc}

      echo Downloading dependencies from Gradle task...

      sh ./gradlew assemble --no-daemon --no-watch-fs --parallel &> /dev/null
    '';
    # perl code mavenizes pathes (com.squareup.okio/okio/1.13.0/a9283170b7305c8d92d25aff02a6ab7e45d06cbe/okio-1.13.0.jar -> com/squareup/okio/okio/1.13.0/okio-1.13.0.jar)
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256:1r01dyvra3qgqqk9alb3wp2b7pzxl6vmp5s97q61h8a9sf27744g";
  };

in stdenv.mkDerivation rec {
  inherit name version src gradlebinSrc nativeBuildInputs;

  patch1Src = ./fix-locate-config.patch;

  buildPhase = ''
    export GRADLE_USER_HOME=$(mktemp -d)
    # point to offline repo
    sed -ie "s#mavenCentral()#mavenLocal(); maven { url '${deps}' }#g" build.gradle
    sed -i '1ipluginManagement { repositories { mavenLocal(); maven { url "${deps}" } } }' settings.gradle
    substituteInPlace gradle/wrapper/gradle-wrapper.properties --replace https\\://services.gradle.org/distributions/gradle-7.0-bin.zip file://${gradlebinSrc}

    patch -p0 < ${patch1Src}
    sh ./gradlew build -x test --offline --no-daemon --no-watch-fs
  '';

  desktopItem = makeDesktopItem {
    type = "Application";
    name = "hmcl";
    desktopName = "HMCL";
    exec = "hmcl";
    icon = "hmcl";
  };

  installPhase = ''
    mkdir -p $out/{bin,share/HMCL}

    cp -R HMCL/build/libs/HMCL-*.SNAPSHOT.jar $out/share/HMCL/HMCL.jar
    install -Dm644 HMCL/src/main/resources/assets/img/icon.png $out/share/icons/hicolor/32x32/apps/hmcl.png

    makeWrapper ${openjdk}/bin/java $out/bin/hmcl \
      --prefix LD_LIBRARY_PATH : ${envLibPath} \
      --run "cd /tmp" \
      --add-flags "-jar $out/share/HMCL/HMCL.jar"

    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  meta = with lib; {
    homepage = "http://openjdk.java.net/projects/openjfx/";
    license = licenses.gpl3;
    description = "A Minecraft Launcher which is multi-functional";
    maintainers = with maintainers; [ "Hentioe" ];
    platforms = [ "x86_64-linux" ];
  };
}
