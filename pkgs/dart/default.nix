{ stdenv, lib, fetchurl, unzip, autoPatchelfHook }:

stdenv.mkDerivation rec {
  name = "dart";
  version = "2.13.4";

  src = fetchurl {
    url =
      "https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-linux-x64-release.zip";
    sha256 = "633a9aa4812b725ff587e2bbf16cd5839224cfe05dcd536e1a74804e80fdb4cd";
  };

  nativeBuildInputs = [ unzip autoPatchelfHook ];

  installPhase = ''
    mkdir -p $out
    cp -R * $out/
  '';

  dontStrip = true;

  meta = with lib; {
    homepage = "https://www.dartlang.org/";
    maintainers = with maintainers; [ "Hentioe" ];
    description =
      "Scalable programming language, with robust libraries and runtimes, for building web, server, and mobile apps";
    longDescription = ''
      Dart is a class-based, single inheritance, object-oriented language
      with C-style syntax. It offers compilation to JavaScript, interfaces,
      mixins, abstract classes, reified generics, and optional typing.
    '';
    platforms = [ "x86_64-linux" ];
    license = licenses.bsd3;
  };
}
