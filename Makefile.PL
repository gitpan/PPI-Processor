use inc::Module::Install;

name          ( 'PPI-Processor'               );
abstract      ( 'Implement a PPI Document processing engine' );
author        ( 'Adam Kennedy<cpan@ali.as>'   );
version_from  ( 'lib/PPI/Processor.pm'        );
license       ( 'perl'                        );

requires      ( 'perl'             => '5.005' );
requires      ( 'Class::Inspector' => '1.07'  );
requires      ( 'File::Find::Rule' => '0.27'  );
requires      ( 'PPI'              => '0.840' );

build_requires( 'File::Spec'       => '0.82'  );
build_requires( 'Test::More'       => '0.47'  );

auto_install();

&WriteAll;
