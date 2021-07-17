{ stdenv, lib, fetchurl, autoPatchelfHook, dpkg, buildFHSUserEnv
, makeDesktopItem, runCommand, xlibs, glib, gnome2, cairo, gdk-pixbuf, nss_3_53
, nspr }:
let
  drvName = "linuxqq-${version}";
  version = "2.0.0-b2";

  linuxqq = stdenv.mkDerivation rec {
    name = "${drvName}-unwrapped";

    fileName = "linuxqq_${version}-1089_amd64.deb";

    src = fetchurl {
      url = "https://down.qq.com/qqweb/LinuxQQ/${fileName}";
      sha256 =
        "f8e96b0fa3a09f7d36385a446ddfd86b173cf1cef1eb0f40493250538807c52c";
    };

    nativeBuildInputs = [ autoPatchelfHook ];

    buildInputs = [
      dpkg
      xlibs.libX11
      glib
      gnome2.gtk
      gnome2.pango
      cairo
      gdk-pixbuf
      nss_3_53
      nspr
    ];

    sourceRoot = ".";

    unpackCmd = "dpkg-deb -x ${src} .";

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out
      cp -R usr/local/bin usr/local/lib usr/local/share usr/share $out/
    '';
  };

  fhsEnv = buildFHSUserEnv {
    name = "${drvName}-fhs-env";
    multiPkgs = pkgs:
      [
        (runCommand "qq-share" { } ''
          mkdir -p $out/share
          ln -s ${linuxqq}/share/tencent-qq $out/share/tencent-qq
        '')
      ];
  };

in runCommand drvName {
  startScript = ''
    #!${fhsEnv}/bin/${drvName}-fhs-env
    ${linuxqq}/bin/qq
  '';

  meta = with lib; {
    homepage = "https://im.qq.com/linuxqq/";
    description = "QQ Linux版-从心出发·趣无止境";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ Hentioe ];
  };
} ''
  mkdir -p $out/{bin,share/tencent-qq}

  echo -n "$startScript" > $out/bin/qq
  chmod +x $out/bin/qq

  # fix the path in the desktop file
  cp -R \
    ${linuxqq}/share/applications \
    $out/share
  substituteInPlace \
    $out/share/applications/qq.desktop \
    --replace /usr/local/ $out/

    ln -sf ${linuxqq}/share/tencent-qq/qq.png $out/share/tencent-qq/qq.png
''
