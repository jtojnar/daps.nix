{ p ? import <nixpkgs> {} }:

let

  pkgs = import (p.fetchFromGitHub {
    owner = "nixos";
    repo = "nixpkgs";
    rev = "c19136c4c9fa1d448038023fdfedd22108a33981";
    sha256 = "1vhb0s9zv3769bv0paj2dsnqgv45g9ijj07na9qphyx3c680i4wf";
  }) {};

  inherit (pkgs) stdenv fetchurl fetchFromGitHub runCommand libxml2
    libxslt w3m remake fop jing trang imagemagick python3 dia exiftool
    ghostscript inkscape optipng xfig poppler_utils docbook_xml_dtd_45
    docbook_xml_dtd_44 docbook_xml_dtd_43 docbook_xml_dtd_42
    docbook_xml_dtd_412 docbook5 docbook5_xsl getopt docbook_xsl
    which xmlstarlet bash autoreconfHook aspellWithDicts findXMLCatalogs

    lib
  ;

  aspell = aspellWithDicts (dicts: [ dicts.en ]);

  daps-src = fetchFromGitHub {
    owner = "openSUSE";
    repo = "daps";
    rev = "b624f6dcf309cebee409f0d3c2fe89a9f03f7559";
    sha256 = "086bz7xfnzn7ziq0piz9wyghk81n8y4x19xp1i1nhcd00q7y6wcq";
  };

  daps-catalog = runCommand "daps-catalog" {
    propagatedNativeBuildInputs = [ findXMLCatalogs ];
    } ''
      mkdir -p $out/share/xml/
      cp ${daps-src}/etc/catalog.generic $out/share/xml/catalog.xml
      cp -r ${daps-src}/daps-xslt $out/share/xml/

      substituteInPlace $out/share/xml/catalog.xml \
        --replace "../daps-xslt/" "$out/share/xml/daps-xslt/"
    '';

  svg-src = fetchurl {
    url = "https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd";
    sha256 = "0kvf5bfr55flg4p5yrn5vrbph77ikl6bdrblmpysbj2d5zkrhmbl";
  };

  # Can be made into standalone package https://gist.github.com/jtojnar/04ea4d1215933f692b3e53eb5d99bc99
  svg = runCommand "svg" {
      nativeBuildInputs = [ libxml2 ];
      propagatedNativeBuildInputs = [ findXMLCatalogs ];
    } ''
    prefix=$out/share/xml/svg-1.1
    mkdir -p $prefix
    cp ${svg-src} $prefix

    # Generate an XML catalog.
    cat=$prefix/catalog.xml
    xmlcatalog --noout --create $cat
    xmlcatalog --noout --add public "-//W3C//DTD SVG 1.1 Basic//EN" svg11.dtd $cat
  '';
in
stdenv.mkDerivation rec {
  name = "daps-20171116";

  src = daps-src;

  buildInputs = [
    autoreconfHook
    libxml2 libxslt w3m remake fop jing trang imagemagick python3 dia
    exiftool ghostscript inkscape optipng xfig poppler_utils getopt
    which xmlstarlet aspell
    docbook5 docbook5_xsl svg
    docbook_xml_dtd_45 docbook_xml_dtd_44 docbook_xml_dtd_43
    docbook_xml_dtd_42 docbook_xml_dtd_412 docbook_xsl

    daps-catalog
  ];

  configureFlags = [
    "--enable-edit-rootcatalog=no"
  ];

  patches = [
    ./daps-init-xmlstarlet.patch
    ./daps-init-source-permissions.patch
    ./daps-path.patch
    ./tar-dont-preserve-perms.patch
    ./root_catalog.patch
  ];

  inherit xmlstarlet;

  mypath = lib.makeBinPath buildInputs;

  postPatch = ''
    substituteAllInPlace ./bin/daps-init
    substituteAllInPlace ./bin/daps

    for f in "./lib/daps_functions" "./make/common_variables.mk" "./bin/daps-auto.pl"; do
      substituteInPlace "$f" \
        --replace "/bin/bash" "${bash}/bin/bash"
    done

    patchShebangs .
    for f in $(find . -type f | grep -v '.png$'); do
      substituteInPlace "$f" \
        --replace "/usr/bin/xsltproc" "${libxslt.bin}/bin/xsltproc" \
        --replace /usr/bin/make $(which make) \
        --replace /usr/bin/xmlstarlet ${xmlstarlet}/bin/xmlstarlet \
        --replace /usr/bin/xmlcatalog ${libxml2}/bin/xmlcatalog \
        --replace /usr/share/daps $out/share/daps \
        --replace /usr/bin/remake ${remake}/bin/remake \
        --replace /usr/bin/aspell ${aspell}/bin/aspell
    done
  '';
}
