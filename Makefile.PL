use ExtUtils::MakeMaker;
# $Author: brian $
# $Id: Makefile.PL,v 1.2 2001/03/10 16:41:24 brian Exp $

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'  	 	=> 'Business::ISBN',
    'VERSION_FROM' 	=> 'ISBN.pm', # finds $VERSION
);
