class imagemagick
{
  $packages = [ ImageMagick, ImageMagick-perl ]

  package { $packages: ensure => installed }
}
