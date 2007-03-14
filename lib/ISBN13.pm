# $Revision: 2.3 $
# $Id: ISBN13.pm,v 2.3 2007/03/14 07:31:26 comdog Exp $
package Business::ISBN13;
use strict;
use base qw(Business::ISBN);

use Business::ISBN qw(:all);
use Data::Dumper;

use subs qw( 
	_checksum
	INVALID_COUNTRY_CODE
	INVALID_PUBLISHER_CODE
	BAD_CHECKSUM
	GOOD_ISBN
	BAD_ISBN
	);
use vars qw( 
	$VERSION 
	$debug
	);

use Carp qw(carp croak cluck);

my $debug = 0;

($VERSION)   = q$Revision: 2.3 $ =~ m/(\d+\.\d+)\s*$/;

sub _max_length { 10 }

sub _set_type     { $_[0]->{type} = 'ISBN13' }

sub _parse_prefix 
	{ 
	( $_[0]->isbn =~ /\A(\d\d\d)(.{10})\z/g )[0];
	}

sub _set_prefix   
	{ 
	croak "Cannot set prefix [$_[1]] on an ISBN-13"
		unless $_[1] =~ m/\A97[89]\z/;
	
	$_[0]->{prefix} = $_[1];
	}

sub _hyphen_positions 
	{ 
	[
	$_[0]->_prefix_length,
	$_[0]->_prefix_length + $_[0]->_group_code_length,
	$_[0]->_prefix_length + $_[0]->_group_code_length + $_[0]->_publisher_code_length,
	$_[0]->_checksum_pos,
	]
	}

sub as_isbn10
	{
	my $self = shift;

	return unless $self->prefix eq '978';

	my $isbn10 = Business::ISBN->new( 
		substr( $self->isbn, 3 )
		);
	$isbn10->fix_checksum;

	return $isbn10;
	}

sub as_isbn13
	{
	my $self = shift;

	my $isbn13 = Business::ISBN->new( $self->as_string );
	$isbn13->fix_checksum;

	return $isbn13;
	}

#internal function.  you don't get to use this one.
sub _checksum
	{
	my $data = $_[0]->isbn;

	return unless defined $data;

	my @digits = split //, $data;
	my $sum    = 0;

	foreach my $index ( 0, 2, 4, 6, 8, 10 )
		{
		$sum +=     substr($data, $index, 1);
		$sum += 3 * substr($data, $index + 1, 1);
		}

	#take the next higher multiple of 10 and subtract the sum.
	#if $sum is 37, the next highest multiple of ten is 40. the
	#check digit would be 40 - 37 => 3.
	my $checksum = ( 10 * ( int( $sum / 10 ) + 1 ) - $sum ) % 10;

	return $checksum;
	}


1;

__END__

=head1 NAME

Business::ISBN13 - work with 13 digit International Standard Book Numbers

=head1 SYNOPSIS

See L<Business::ISBN>

=head1 DESCRIPTION

See L<Business::ISBN>

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	http://sourceforge.net/projects/perl-isbn/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

brian d foy C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2001-2007, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut
