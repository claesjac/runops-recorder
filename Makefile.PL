use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Runops::Recorder',
    VERSION_FROM      => 'lib/Runops/Recorder.pm', # finds $VERSION
    PREREQ_PM         => {
        Term::Screen    => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Runops/Recorder.pm', # retrieve abstract from module
       AUTHOR         => 'Claes Jakobsson <claesjac@cpan.org>') : ()),
    EXE_FILES               => [qw(bin/rr-viewer)],
);
