class yum
{
  package { "yum-priorities": ensure => latest }
}

class centos
{
  include yum

  $remove = [ 'atk'
            , 'authconfig'
            , 'bitstream-vera-fonts'
            , 'cairo'
            , 'cups-libs'
            , 'dhcpv6-client'
            , 'ecryptfs-utils'
            , 'fontconfig'
            , 'freetype'
            , 'gtk2'
            , 'hdparm'
            , 'hicolor-icon-theme'
            , 'libX11'
            , 'libXau'
            , 'libXcursor'
            , 'libXdmcp'
            , 'libXext'
            , 'libXfixes'
            , 'libXft'
            , 'libXi'
            , 'libXinerama'
            , 'libXrandr'
            , 'libXrender'
            , 'libhugetlbfs'
            , 'libjpeg'
            , 'libpng'
            , 'libtiff'
            , 'pango'
            , 'setserial'
            , 'trousers'
            , 'udftools'
            , 'xorg-x11-filesystem'
            ]

  package { $remove: ensure => absent }
}

