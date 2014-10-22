package Business::ISBN;
use strict;
use subs qw(_common_format _checksum is_valid_checksum);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $debug %country_data);

use Exporter;

my $debug = 0;

@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw(is_valid_checksum ean_to_isbn isbn_to_ean);

$VERSION   = '19990112';

sub new
	{
	my $class       = shift;
	my $common_data = _common_format shift;
	
	return undef unless $common_data;

	my $self  = {};
	bless $self, $class;
	
	$self->{'isbn'}  = $common_data;
	$self->{'positions'} = [9];
	
	# extract the country code
	my $trial_country_code = 0;
	my $country_code_length = 0;
	my $count = 1;
	while( defined ($trial_country_code = substr($self->{'isbn'}, 0, $count++) ) )
		{
		if(defined $country_data{ $trial_country_code } )
			{
			$self->{'country_code'} = $trial_country_code;
			$self->{'country'} =  
				${$country_data{ $trial_country_code }}[0];
			$country_code_length = length $trial_country_code;
			${$self->{'positions'}}[2] = $country_code_length;
			last;
			}
		}
	
	# let's check the publisher code.
	my $trial_publisher_code;
	my $max_publisher_code_length = 10 - 1 - $country_code_length;
	print "Max Publisher Code Length = [$max_publisher_code_length]\n"
		if $debug > 0;
	$count = 1;

	PUBLISHER_CODE:
	while( defined( $trial_publisher_code = substr($self->{'isbn'}, 
	                                      $country_code_length,
	                                      $count++) )  and
	                                      $count < $max_publisher_code_length)
		{
		my $trial_publisher_code_length = length $trial_publisher_code;
		print "Trial Publisher Code = [$trial_publisher_code] length = [$trial_publisher_code_length]\n"
			if $debug > 0;

		my @pairs = @{${$country_data{ $self->{'country_code'} } }[1]};
		PAIR: 
		while( @pairs )
			{
			my $lower_bound = shift @pairs;
			my $upper_bound = shift @pairs;
			my $lower_length = length $lower_bound;
			my $upper_length = length $upper_bound;
			
			print "lower = [$lower_bound] length [$lower_length]\n" if $debug > 0;
			print "upper = [$upper_bound] length [$upper_length]\n" if $debug > 0;	
					
 			#in looking for the publisher code, 00 has a different
			#meaning than 0 (in this case it means that the publisher
			#code is at least two digits).  we have to be careful 
			#because perl will turn 00* into 0 when used as a number
			
			last PAIR           if $trial_publisher_code_length <  $lower_length;
			#last PUBLISHER_CODE if $trial_publisher_code_length >  $upper_length;
			next PAIR unless (     $trial_publisher_code_length >= $lower_length and
			                       $trial_publisher_code_length <= $upper_length );
			print "[ $lower_bound | $trial_publisher_code | $upper_bound ]\n"
				if $debug > 0;
				
			if( $trial_publisher_code >= $lower_bound and
			    $trial_publisher_code <= $upper_bound )
			    {
			    print "successful find: $trial_publisher_code\n" if $debug > 0;
			    
			    $self->{'publisher_code'} = $trial_publisher_code;
				${$self->{'positions'}}[1] = $country_code_length +
					$trial_publisher_code_length;
			    last PUBLISHER_CODE;
			    }
			}  	
		
		}

	#get the book code, which is everything between the
	#publisher code the and the checksum
	$common_data =~ m/  
					$self->{'country_code'} 
					$self->{'publisher_code'}
					(.+)
					([\dxX])
					$
					/x;
	$self->{'article_code'} = $1 if defined $1 and defined $2;
	$self->{'checksum'}     = $2 if defined $1 and defined $2;

	if( is_valid_checksum $self->{'isbn'} and 
	    defined $self->{'country_code'}  and 
	    defined $self->{'publisher_code'} )
	    {
	    $self->{'valid'} = 1;
	    }
	else
		{
		$self->{'valid'} = -3 if not defined $self->{'publisher_code'};
		$self->{'valid'} = -2 if not defined $self->{'country_code'};
		$self->{'valid'} = -1 if not is_valid_checksum $self->{'isbn'};
		}

	return $self;
	}	


#it's your fault if you muck with the internals yourself

sub isbn             { my $self = shift; return $self->{'isbn'} }
sub is_valid         { my $self = shift; return $self->{'valid'} }
sub country_code     { my $self = shift; return $self->{'country_code'} }
sub publisher_code   { my $self = shift; return $self->{'publisher_code'} }
sub article_code     { my $self = shift; return $self->{'article_code'} }
sub checksum         { my $self = shift; return $self->{'checksum'} }
sub hyphen_positions { my $self = shift; return @{$self->{'positions'}} }

	
sub fix_checksum
	{
	my $self = shift;
	
	my $last_char = substr($self->{'isbn'}, 9, 1);
	my $checksum = _checksum $self->isbn;

	substr($self->{'isbn'}, 9, 1) = $checksum;
	
	$self->_check_validity;
	
	return 0 if $last_char eq $checksum;
	return 1;
	}
		
sub as_string
	{
	my $self      = shift;
	my $array_ref = shift;
	
	#this allows one to override the positions settings from the
	#constructor
	$array_ref = $self->{'positions'} unless ref $array_ref eq 'ARRAY';
	
	return undef unless $self->is_valid;
	my $isbn = $self->isbn;
	
	foreach my $position ( sort {$b <=> $a} @$array_ref )
		{
		next if $position > 9 or $position < 1;
		substr($isbn, $position, 0) = '-';
		}
			
	return $isbn;
	}
	
sub as_ean
	{
	my $self = shift;
	
	my $isbn = ref $self ? $self->as_string([]) : _common_format $self;
	
	my $ean = '978' . substr($isbn, 0, 9);;
	
	my $sum = 0;
	foreach my $index ( 0, 2, 4, 6, 8, 10 )
		{
		$sum +=     substr($ean, $index, 1);
		$sum += 3 * substr($ean, $index + 1, 1);
		}
			
	$ean .= 10 - ( $sum % 10 );
	
	return $ean;
	}
	
sub is_valid_checksum
	{
	my $data = _common_format shift;
	
	return 1 if substr($data, 9, 1) eq _checksum $data;
	
	return 0;
	}

sub ean_to_isbn
	{
	my $ean = shift;
	
	$ean =~ s/[^0-9]//g;
	
	return undef unless length $ean == 13;
	return undef unless substr($ean, 0, 3) eq '978';
		
	my $isbn = new Business::ISBN( substr($ean, 3, 9) . '1' );
	
	$isbn->fix_checksum;
	
	return $isbn->as_string([]) if $isbn->is_valid;
	
	return undef;
	}

		
sub isbn_to_ean
	{
	my $isbn = _common_format shift;
	
	return undef unless is_valid_checksum($isbn);
	
	return as_ean($isbn);
	}	
	
#internal function.  you don't get to use this one.
sub _check_validity
	{
	my $self = shift;
	
	if( is_valid_checksum and defined $self->{'country_code'}
	    and defined $self->{'publisher_code'} )
	    {
	    $self->{'valid'} = 1;
	    }
	else
		{
		$self->{'valid'} = -3 if not defined $self->{'publisher_code'};
		$self->{'valid'} = -2 if not defined $self->{'country_code'};
		$self->{'valid'} = -1 if not is_valid_checksum;
		}
	}

#internal function.  you don't get to use this one.
sub _checksum
	{
	my $data = _common_format shift;
	
	return undef unless $data;
	
	my @digits = split //, $data;
	my $sum    = 0;		

	foreach( reverse 2..10 )
		{
		$sum += $_ * (shift @digits);
		}
	
	#return what the check digit should be
	my $checksum = (11 - ($sum % 11))%11;
	
	$checksum = 'X' if $checksum == 10;
	
	return $checksum;
	}
	
#internal function.  you don't get to use this one.
sub _common_format
	{
	#we want uppercase X's
	my $data = uc shift;
	
	#get rid of everything except decimal digits and X
	$data =~ s/[^0-9X]//g;
	
	return $data if $data =~ m/
	                  ^     	#anchor at start  
					\d{9}[0-9X]
	                  $			#anchor at end
	                  /x;
	                  
	return undef;
	}

BEGIN { 
%country_data = (
965 => [ 'ISRAEL', ['00',19,200,599,7000,7999,90000,99999]],
982 => [ 'SOUTH PACIFIC', ['0','0']],
9989 => [ 'MACEDONIA', ['0',2,30,59,600,969,9700,9999]],
9983 => [ 'GAMBIA', [80,94,950,989,9900,9999]],
87 => [ 'DENMARK', ['00',29,400,649,7000,7999,85000,94999,970000,999999]],
99903 => [ 'MAURITIUS', ['0',1,20,89,900,999]],
953 => [ 'CROATIA', ['0','0',10,14,150,599,6000,9599,96000,99999]],
975 => [ 'TURKEY', ['00',29,300,599,6000,9199,92000,97999]],
957 => [ 'TAIWAN', ['00',43,440,849,8500,9699,97000,99999]],
85 => [ 'BRAZIL', ['00',19,200,699,7000,8499,85000,89999,900000,999999]],
5 => [ 'RUSSIAN FEDERATION', ['00',19,200,699,7000,8499,85000,89999,900000,949999,9500000,9999999]],
971 => [ 'PHILIPPINES', ['00',49,500,849,8500,9099,91000,99999]],
970 => [ 'MEXICO', ['00',59,600,899,9000,9099,91000,99999]],
968 => [ 'MEXICO', [10,39,400,499,800,899,6000,7999]],
99917 => [ 'BRUNEI', ['0','0']],
960 => [ 'GREECE', ['00',19,200,699,7000,8499,85000,99999]],
966 => [ 'UKRAINE', ['00',29,500,599,7000,7999,90000,99999]],
9979 => [ 'ICELAND', ['0',4,50,79,800,899,9000,9999]],
99916 => [ 'NAMIBIA', ['0',2,30,69,700,999]],
952 => [ 'FINLAND', ['00',19,89,94,200,499,5000,8899,9500,9899,99000,99999]],
951 => [ 'FINLAND', ['0',1,20,54,550,899,8900,9499,95000,99999]],
9974 => [ 'URAGUAY', ['0',2,30,54,550,749,7500,9999]],
978 => [ 'NIGERIA', ['000',199,2000,2999,30000,99999]],
'0' => [ 'UK/US ENGLISH', ['00',19,200,699,7000,8499,85000,89999,900000,949999,9500000,9999999]],
1 => [ 'UK/US ENGLISH', [55000,86979,869800,998999,9999900,9999999]],
99914 => [ 'SURINAME', ['0',4,50,89,900,949]],
956 => [ 'CHILE', ['00',19,200,699,7000,9999]],
91 => [ 'SWEDEN', ['0',1,20,49,500,649,7000,7999,85000,94999,970000,999999]],
984 => [ 'BANGLADESH', ['00',39,400,799,8000,8999,90000,99999]],
964 => [ 'IRAN', ['00',29,300,549,5500,8999,90000,99999]],
90 => [ 'NETHERLANDS/BELGIUM', ['00',19,200,499,5000,6999,70000,79999,800000,899999,9000000,9999999]],
958 => [ 'COLUMBIA', ['0',59,600,899,9000,9499,95000,99999]],
972 => [ 'PORTUGAL', ['0',1,20,54,550,799,8000,9499,95000,99999]],
985 => [ 'BELARUS', ['00',39,400,599,6000,8999,90000,99999]],
9970 => [ 'UGANDA', ['00',39,400,899,9000,9999]],
983 => [ 'MALAYSIA', ['0',4,50,79,800,899,9000,9899,99000,99999]],
967 => [ 'MALAYSIA', ['0',5,60,89,900,989,9900,9989,99900,99999]],
9975 => [ 'MOLDOVA', ['0',4,50,89,900,949,9500,9999]],
89 => [ 'KOREA', ['00',29,300,699,7000,8499,85000,94999,950000,999999]],
9960 => [ 'SAUDI ARABIA', ['00',59,600,899,9000,9999]],
7 => [ 'PEOPLE\'S REP. CHINA', ['00','09',100,499,5000,7999,80000,89999,900000,999999]],
9961 => [ 'ALGERIA', ['0',4,50,79,800,949,9500,9999]],
9980 => [ 'PAPUA NEW GUINEA', ['0',3,40,89,900,989,9900,9999]],
987 => [ 'ARGENTINA', ['00',49,500,899,9000,9499,99000,99999]],
950 => [ 'ARGENTINA', ['00',49,500,899,9000,9899,99000,99999]],
99918 => [ 'FAROE ISLANDS', ['0',3,40,89,900,999]],
969 => [ 'PAKISTAN', ['0',1,20,39,400,799,8000,9999]],
959 => [ 'CUBA', ['00',19,200,699,7000,8499]],
9972 => [ 'PERU', ['0',3,40,59,600,899,9000,9999]],
83 => [ 'POLAND', ['00',91,200,699,7000,8499,85000,89999,900000,999999]],
82 => [ 'NORWAY', ['00',19,200,699,7000,8999,90000,98999,990000,999999]],
88 => [ 'ITALY', ['00',19,200,699,7000,8499,85000,89999,900000,999999]],
81 => [ 'INDIA', ['00',19,200,699,7000,8499,85000,89999,900000,999999]],
954 => [ 'BULGARIA', ['00',39,400,799,8000,8999,90000,99999]],
980 => [ 'VENEZUELA', ['00',19,200,599,6000,9999]],
99909 => [ 'MALTA', ['0',3,40,94,950,999]],
3 => [ 'GERMANY', ['00',19,200,699,7000,8499,85000,89999,900000,949999,9500000,9899999]],
955 => [ 'SRI LANKA', ['0',1,20,54,550,899,9000,9499,95000,99999]],
9987 => [ 'TANZANIA', ['00',39,400,879,8800,9999]],
9976 => [ 'TANZANIA', ['0',5,60,89,900,989,9990,9999]],
80 => [ 'CZECHOSLOVAKIA', ['00',19,200,699,7000,8499,85000,89999,900000,999999]],
99913 => [ 'ANDORRA(NOT USED)', ['0','0']],
962 => [ 'HONG KONG', ['00',19,200,699,7000,8499]],
84 => [ 'SPAIN', ['00',19,200,699,7000,8499,9700,9999,85000,89999,95000,96999,900000,949999]],
976 => [ 'CARICOM', ['0',3,40,59,600,799,8000,9999]],
963 => [ 'HUNGARY', ['00',19,200,699,7000,8499,85000,89999]],
99911 => [ 'LESOTHO', ['00',59,600,999]],
9988 => [ 'GHANA', ['0',2,30,54,550,749,7500,9999]],
9964 => [ 'GHANA', ['0',6,70,94,950,999]],
961 => [ 'SLOVENIA', ['00',19,200,599,6000,8999,90000,94999]],
9984 => [ 'LATVIA', ['00',49,500,899,9000,9999]],
9978 => [ 'ECUADOR', ['00',94,950,989,9900,9999]],
86 => [ 'YUGOSLAVIA', ['00',29,300,699,7000,7999,80000,89999,900000,999999]],
974 => [ 'THAILAND', ['00',19,200,699,7000,8499,85000,89999]],
9963 => [ 'CYPRUS', ['0',2,30,54,550,749,7500,9999]],
973 => [ 'ROMANIA', ['0',1,20,54,550,899,9000,9499,95000,99999]],
99920 => [ 'ANDORRA', ['0',4,50,89,900,999]],
981 => [ 'SINGAPORE', ['00',19,200,299,3000,9999]],
9971 => [ 'SINGAPORE', ['0',5,60,89,900,989,9900,9999]],
977 => [ 'EGYPT', ['00',19,200,499,5000,6999,70000,99999]],
4 => [ 'JAPAN', ['00',19,200,699,7000,8499,85000,89999,900000,949999,9500000,9999999]],
99919 => [ 'BENIN', ['0',2,40,69,900,999]],
92 => [ 'UNESCO', ['0',5,60,79,800,899,9000,9999]],
9965 => [ 'KAZAKHSTAN', ['00',39,400,899,9000,9999]],
9981 => [ 'MOROCCO', ['0',1,20,79,800,949,9500,9999]],
9985 => [ 'ESTONIA', ['0',4,50,79,800,899,9000,9999]],
99904 => [ 'NETHERLANDS ANTILLES', ['0',4,60,79,900,999]],
9982 => [ 'ZAMBIA', ['00',30,800,889,9900,9999]],
2 => [ 'FRANCE/FRENCH', ['00',19,200,399,500,699,7000,8399,84000,89999,900000,949999,9500000,9999999]],
99915 => [ 'MALDIVES', ['0',4,50,79,800,999]],
93 => [ 'INDIA (NOT USED)', ['0','0']],
9977 => [ 'COSTA RICA', ['00',89,900,989,9900,9999]],
9968 => [ 'COSTA RICA', ['0','0',10,69,700,969,9700,9999]],
9966 => [ 'KENYA', ['00',69,800,959,9600,9999]],
99921 => [ 'QATAR', ['0',1,20,69,700,999]],
979 => [ 'INDONESIA', ['0','0',20,29,400,699,8000,9499,95000,99999]],
99908 => [ 'MALAWI', ['0','0',10,89,900,999]],
9973 => [ 'TUNISIA', ['0','0',10,69,700,969,9700,9999]],
99912 => [ 'BOTSWANA', ['0',5,60,89,900,999]],
9986 => [ 'LITHUANIA', ['00',39,400,899,9000,9999]]
);
}

1;

__END__

=head1 NAME

Business::ISBN - work with International Standard Book Numbers

=head1 SYNOPSIS

	use Business::ISBN;
	
	$isbn_object = new Business::ISBN('1565922573');
	$isbn_object = new Business::ISBN('1-56592-257-3');
		
	#print the ISBN with hyphens at positions specified
	#by constructor
	print $isbn_object->as_string;
	
	#print the ISBN with hyphens at specified positions.
	#this not does affect the default positions
	print $isbn_object->as_string([]);
	
	#print the country code or publisher code
	print $isbn->country_code;
	print $isbn->publisher_code;
	
	#check to see if the ISBN is valid
	$isbn_object->is_valid;
	
	#fix the ISBN checksum.  BEWARE:  the error might not be
	#in the checksum!
	$isbn_object->fix_checksum;

	#EXPORTABLE FUNCTIONS
	
	use Business::ISBN qw( is_valid_checksum isbn_to_ean ean_to_isbn );
	
	#verify the checksum
	if( is_valid_checksum('0123456789') ) { ... }
	
	#convert to EAN (European Article Number)
	$ean = isbn_to_ean('1565921496');

	#convert from EAN (European Article Number)
	$isbn = ean_to_isbn('9781565921498');
	
=head1 DESCRIPTION

=head2 new($isbn)

The constructor accepts a scalar representing the ISBN.

The string representing the ISBN may contain characters
other than [0-9xX], although these will be removed in the
internal representation.  The resulting string must look
like an ISBN - the first nine characters must be digits and
the tenth character must be a digit, 'x', or 'X'.

The constructor attempts to determine the country
code and the publisher code.  If these data cannot
be determined, the constructor returns an error
number:

	-3 Could not determine publisher code
	-2 Could not determine country code
	-1 ISBN is not valid

The string passed as the ISBN need not be a valid ISBN as
long as it superficially looks like one.  This allows one to
use the C<fix_checksum()> method.  Despite the disclaimer in
the discussion of that method, the author has found it
extremely useful.  One should check the validity of the ISBN
with C<is_valid()> rather than relying on the return value
of the constructor.  If all one wants to do is check the
validity of an ISBN, one can skip the object-oriented 
interface and use the c<is_valid_checksum()> function
which is exportable on demand.

If the constructor decides it can't create an object, it
returns undef.  It may do this if the string passed as the
ISBN can't be munged to the internal format.

=head2 $obj->publisher_code

Returns the publisher code.

=head2 $obj->country_code

Returns the country code.

=head2 $obj->hyphen_positions

Returns the list of hyphen positions as determined from the 
country and publisher codes.  the C<as_string> method provides
a way to temporarily override these positions and to even
forego them altogether.

=head2 $obj->as_string(),  $obj->as_string([])

Return the ISBN as a string.  This function takes an
optional anonymous array (or array reference) that specifies
the placement of hyphens in the string.  An empty list
produces a string with no hyphens.

The positions specified in the passed anonymous array
are only used for one method use and do not replace
the values specified by the constructor.

Positions less than 1 and greater than 9 are silently
ignored.

A terminating 'x' is changed to 'X'.

=head2  $obj->is_valid()

Returns 1 if the checksum is valid and the country and
publisher codes are defined.

Returns -1 if the ISBN does not pass the checksum test.  
The constructor accepts invalid ISBN's so that
they might be fixed with C<fix_checksum>.  

Returns -2 if a country code could not be determined (relies
on a valid checksum).

Returns -3 if a publisher code could not be determined (relies
on a valid checksum and country code). 

=head2  $obj->fix_checksum()

Replace the tenth character with the checksum the
corresponds to the previous nine digits.  This does not
guarantee that the ISBN corresponds to the product one
thinks it does, or that the ISBN corresponds to any product
at all.  It only produces a string that passes the checksum
routine.  If the ISBN passed to the constructor was invalid,
the error might have been in any of the other nine positions.

=head2  $obj->as_ean()

Converts the ISBN to the equivalent EAN (European Article Number).
No pricing extension is added.  Returns the EAN as a string.  This
method can also be used as an exportable function since it checks
its argument list to determine what to do.

=head1 EXPORTABLE FUNCTIONS

Some functions can be used without the object interface.  These
do not use object technology behind the scenes.

=head2 is_valid_checksum('1565921496')

Takes the ISBN string and runs it through the checksum
comparison routine.  Returns 1 if the ISBN is valid, 0 otherwise.

=head2 isbn_to_ean('1565921496')

Takes the ISBN string and converts it to the equivalent
EAN string.  This function checks for a valid ISBN and will return
undef for invalid ISBNs, otherwise it returns the EAN as a string.
Uses as_ean internally, which checks its arguments to determine
what to do.

=head2 ean_to_isbn('9781565921498')

Takes the EAN string and converts it to the equivalent
ISBN string.  This function checks for a valid ISBN and will return
undef for invalid ISBNs, otherwise it returns the EAN as a string.
Uses as_ean internally, which checks its arguments to determine
what to do.

=head1 AUTHOR

brian d foy <comdog@computerdog.com>
please see <URL:http://computerdog.com/brian/style.html> for 
guidelines on proper attribution.

Copyright 1998, Smith Renaud, Inc. 

The coding of this module was supported by Smith Renaud, Inc. 
<URL:http://www.smithrenaud.com>.  This module is released under 
the terms of the Perl Artistic License.

Country code and publisher code graciously provided by Steve
Fisher <stevef@teleord.co.uk> of Whitaker (the UK ISBN folks
and the major bibliographic data provider in the UK).
"Whitaker - helping to link authors to readers worldwide"

Thanks to Julie Koo of Kaya Publishing <URL:http://www.kaya.com>
for useful discussions.

Thanks to Mark W. Eichin <eichin@thok.org> for suggestions and
discussions on EAN support.
=cut
