{ stdenv, lib, fetchurl, unzip, autoPatchelfHook }:
stdenv.mkDerivation rec {
  name = "${pName}-${version}";
  version = "1.2.0";
  pName = "besttrace";

  src = fetchurl {
    url = "https://cdn.ipip.net/17mon/besttrace4linux.zip";
    sha256 = "6f759c09c84249566c47c5ab2b2001f581b3221509b9ca8606e6b80bedccaae7";
  };

  nativeBuildInputs = [ unzip autoPatchelfHook ];

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp ${pName} $out/bin/
    chmod +x $out/bin/${pName}
  '';

  meta = with lib; {
    homepage = "https://www.ipip.net/product/client.html";
    description = "BestTrace";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ "Hentioe" ];
  };
}
