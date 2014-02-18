requires "Carp" => "0";
requires "Fcntl" => "0";
requires "IO::Socket" => "0";
requires "MIME::Base64" => "0";
requires "Time::Local" => "0";
requires "bytes" => "0";
requires "perl" => "5.006";
requires "strict" => "0";
requires "warnings" => "0";
recommends "HTTP::CookieJar" => "0.001";
recommends "IO::Socket::IP" => "0.25";
recommends "IO::Socket::SSL" => "1.42";
recommends "Mozilla::CA" => "20120823";
recommends "Net::SSLeay" => "1.49";
suggests "IO::Socket::SSL" => "1.56";

on 'test' => sub {
  requires "Data::Dumper" => "0";
  requires "Exporter" => "0";
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Basename" => "0";
  requires "File::Spec" => "0";
  requires "File::Spec::Functions" => "0";
  requires "File::Temp" => "0";
  requires "IO::Dir" => "0";
  requires "IO::File" => "0";
  requires "IO::Socket::INET" => "0";
  requires "IPC::Cmd" => "0";
  requires "List::Util" => "0";
  requires "Test::More" => "0.96";
  requires "open" => "0";
  requires "version" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "0";
  recommends "CPAN::Meta::Requirements" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5.013";
  requires "Dist::Zilla::Plugin::Prereqs" => "0";
  requires "Dist::Zilla::Plugin::RemovePrereqs" => "0";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0.060";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::More" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};
