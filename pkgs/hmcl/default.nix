{ stdenv, lib, fetchurl, makeDesktopItem, copyDesktopItems, makeWrapper, unzip
, openjdk, gradle, perl }:

let
  name = "hmcl";
  version = "git-javafx";

  src = fetchurl {
    url = "https://github.com/huanghongxun/HMCL/archive/refs/heads/javafx.zip";
    sha256 = "8cdb07f4868e085ac576e178417a675d99fa8739556647bd5a462c9ebcdac238";
  };

  gradlebinSrc = fetchurl {
    url = "https://services.gradle.org/distributions/gradle-7.0-bin.zip";
    sha256 = "eb8b89184261025b0430f5b2233701ff1377f96da1ef5e278af6ae8bac5cc305";
  };

  nativeBuildInputs = [ unzip openjdk copyDesktopItems makeWrapper ];

  unpackCmd = "unzip $src &> /dev/null";

  deps = stdenv.mkDerivation {
    pname = "${name}-deps";
    inherit version src unpackCmd gradlebinSrc;

    nativeBuildInputs = nativeBuildInputs ++ [ perl ];

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d)
      substituteInPlace gradle/wrapper/gradle-wrapper.properties --replace https\\://services.gradle.org/distributions/gradle-7.0-bin.zip file://${gradlebinSrc}

      echo Extract dependencies from gradle tasks...

      sh ./gradlew --no-daemon --no-watch-fs &> /dev/null
    '';
    # perl code mavenizes pathes (com.squareup.okio/okio/1.13.0/a9283170b7305c8d92d25aff02a6ab7e45d06cbe/okio-1.13.0.jar -> com/squareup/okio/okio/1.13.0/okio-1.13.0.jar)
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256:1gpb2kfrmwkj7i7krixsxdz8i7y68x9zsd16llshfas6ljl2sh92";
  };

in stdenv.mkDerivation rec {
  inherit name version src gradlebinSrc nativeBuildInputs unpackCmd;

  patch1Src = ./fix-locate-config.patch;

  buildPhase = ''
    export GRADLE_USER_HOME=$(mktemp -d)
    # point to offline repo
    sed -ie "s#mavenCentral()#mavenLocal(); maven { url '${deps}' }#g" build.gradle
    sed -i '1ipluginManagement { repositories { mavenLocal(); maven { url "${deps}" } } }' settings.gradle
    substituteInPlace gradle/wrapper/gradle-wrapper.properties --replace https\\://services.gradle.org/distributions/gradle-7.0-bin.zip file://${gradlebinSrc}

    patch -p0 < ${patch1Src}
    sh ./gradlew build --offline --no-daemon --no-watch-fs
  '';

  desktopItem = makeDesktopItem {
    type = "Application";
    name = "hmcl";
    desktopName = "HMCL";
    exec = "hmcl";
    icon = "hmcl";
  };

  desktopItems = [ desktopItem ];

  installPhase = ''
    mkdir -p $out/{bin,share}

    cp HMCL/build/libs/HMCL-*.SNAPSHOT.jar $out/share/HMCL.jar
    install -Dm644 HMCL/src/main/resources/assets/img/icon.png $out/share/icons/hicolor/32x32/apps/hmcl.png
    makeWrapper ${openjdk}/bin/java $out/bin/hmcl \
      --add-flags "-jar $out/share/HMCL.jar"
  '';

  meta = with lib; {
    homepage = "http://openjdk.java.net/projects/openjfx/";
    license = licenses.gpl3;
    description = "A Minecraft Launcher which is multi-functional";
    maintainers = with maintainers; [ "Hentioe" ];
    platforms = [ "x86_64-linux" ];
  };
}
