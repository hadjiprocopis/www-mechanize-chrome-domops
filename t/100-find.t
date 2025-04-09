#!/usr/bin/env perl

###################################################################
#### NOTE env-var PERL_TEST_TEMPDIR_TINY_NOCLEANUP=1 will stop erasing tmp files
###################################################################

use strict;
use warnings;

use lib 'blib/lib';

#use utf8;

our $VERSION = '0.10';

use Test::More;
use Test2::Plugin::UTF8; # rids of the Wide Character in TAP message!
use FindBin;
use WWW::Mechanize::Chrome;
use Data::Roundtrip qw/perl2dump no-unicode-escape-permanently/;
use Log::Log4perl qw(:easy);
use Test::TempDir::Tiny;
use File::Spec;

use WWW::Mechanize::Chrome::DOMops qw/
	zap
	find
	VERBOSE_DOMops
/;

# This is for the mech obj, Set priority of root logger to ERROR
Log::Log4perl->easy_init($ERROR);

# At this point we are not sure if the google-chrome binary
# is installed or not, so we will test the creation of a simple
# mech object in an eval and if that fails, then we EXIT this
# test file gracefully without any failure (just a warning
# for the user)
my $cv = eval { WWW::Mechanize::Chrome->chrome_version() };
if( $@ne'' ){
	plan skip_all => "$@\nError: you need to install the google-chrome executable before continuing.\n";
	exit 0; # gracefull exit, all tests have passed! hopefully the user trying to install it has seen this message.
}
diag "found google-chrome executable, version:\n$cv";

my $curdir = $FindBin::Bin;

# verbosity can be 0, 1, 2, 3
my $VERBOSITY = 0;

$WWW::Mechanize::Chrome::DOMops::VERBOSE_DOMops = $VERBOSITY;

# the URL to get
my $URL = "file://${curdir}/t-data/site1/content.html";
# then we look for some elements
# WARNING: HTML from URL may change so these tests may start failing at some point!

# if for debug you change this make sure that it has path in it e.g. ./xyz
my $tmpdir = tempdir(); # will be erased unless a BAIL_OUT or env var set
ok(-d $tmpdir, "output dir exists");

my $js_outfile_tmp = File::Spec->catdir($tmpdir, 'outfile.js');
diag "Using temp dir '$tmpdir' ...";

my ($element_tagname, $element_id, $element_classname);

my @known_selectors = ('element-name', 'element-class', 'element-tag', 'element-id', 'element-cssselector');
my @known_callbacks = ('find-cb-on-matched', 'find-cb-on-matched-and-their-children');

my %default_mech_params = (
	headless => 1,
#	log => $mylogger,
	launch_arg => [
		'--window-size=600x800',
		'--password-store=basic', # do not ask me for stupid chrome account password
#		'--remote-debugging-port=9223',
#		'--enable-logging', # see also log above
		'--disable-gpu',
		'--no-sandbox',
		'--ignore-certificate-errors',
		'--disable-background-networking',
		'--disable-client-side-phishing-detection',
		'--disable-component-update',
		'--disable-hang-monitor',
		'--disable-save-password-bubble',
		'--disable-default-apps',
		'--disable-infobars',
		'--disable-popup-blocking',
	],
);

my $mech_obj = eval {
	WWW::Mechanize::Chrome->new(%default_mech_params)
};
ok($@eq'', "WWW::Mechanize::Chrome->new() : called via an eval() and did not fail.") or BAIL_OUT("failed to create WWW::Mechanize::Chrome object vial an eval() : $@");
ok(defined($mech_obj), "WWW::Mechanize::Chrome->new() : called.") or BAIL_OUT("failed to create WWW::Mechanize::Chrome object");

# JS console.log() messages go to warnout if VERBOSITY is > 2
# we need to keep $console in scope!
my $console = $VERBOSITY > 2 ? $mech_obj->add_listener('Runtime.consoleAPICalled', sub {
	  warn
	      "js console: "
	    . join ", ",
	      map { $_->{value} // $_->{description} }
	      @{ $_[0]->{params}->{args} };
	}) : undef
;

my %tests = (
	# in params specify the selector to select elements known selectors:
	#   'element-name', 'element-class', 'element-tag', 'element-id', 'element-cssselector'
	# each selector can contain a single criterion or an array of them
	# e.g. 'element-id' => ['nav-id-1'] OR 'element-tag' => 'nav',
	# All html elements matched will be combined either with a Union ('||'=>1)
	# or an Intersection ('&&'=>1)
	# specify also what html element ids are expected and not expected for checking the result
	'test01' => {
		'params' => {
			'element-id' => ['nav-id-1'],
			'element-tag' => 'nav',
			'&&' => 1, # intersection (which is the default)
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'li-id-2', 'span-id-1', 'span-id-2'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
	},
	'test02' => {
		'params' => {
			'element-id' => ['div-id-1'],
			'element-tag' => ['nav'],
			'||' => 1, # union (meaning the addition of the two sets without duplicates)
			'element-information-from-matched' => <<'EOJ',
// return anything but make sure you also include 'id' because tests need it
return {"blah" : htmlElement.tagName, "blih" : htmlElement.hasAttribute("role") ? htmlElement.getAttribute("role") : "<no role>", "id" : htmlElement.id};
EOJ
		},
		'must-be-returned' => ['div-id-1', 'div-id-1-1', 'nav-id-1', 'li-id-1', 'li-id-2', 'span-id-1', 'span-id-2'],
		'must-not-be-returned' => ['header-id-1', 'div-id-2', 'div-id-2-1'],
		'keys-in-found' => ['blah', 'blih'],
	},
	'test02-exception' => {
		'params' => {
			'element-id' => ['div-id-1'],
			'element-tag' => ['nav'],
			'||' => 1, # union (meaning the addition of the two sets without duplicates)
			'element-information-from-matched' => <<'EOJ',
throw new Error("testing exceptions");
EOJ
		},
		'must-be-returned' => ['div-id-1', 'div-id-1-1', 'nav-id-1', 'li-id-1', 'li-id-2', 'span-id-1', 'span-id-2'],
		'must-not-be-returned' => ['header-id-1', 'div-id-2', 'div-id-2-1'],
		'keys-in-found' => ['blah', 'blih'],
	},
	'test03' => {
		'params' => {
			'element-class' => ['div-class-1'],
		},
		'must-be-returned' => ['div-id-1', 'div-id-1-1'],
		'must-not-be-returned' => ['header-id-1', 'div-id-2', 'div-id-2-1', 'nav-id-1', 'li-id-1', 'li-id-2'],
	},
	'test04' => {
		'params' => {
			'element-cssselector' => ['nav#nav-id-1'],
			'element-information-from-matched' => <<'EOJ',
// return anything but make sure you also include 'id' because tests need it
return {"blah" : htmlElement.tagName, "blih" : htmlElement.hasAttribute("role") ? htmlElement.getAttribute("role") : "<no role>", "id" : htmlElement.id};
EOJ
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
		'keys-in-found' => ['blah', 'blih'],
	},
	'test05' => {
		'params' => {
			'element-tag' => ['div'],
			'element-cssselector' => ['nav#nav-id-1'],
			'||' => 1, # union (meaning the addition of the two sets without duplicates)
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
		'must-not-be-returned' => ['header-id-1'],
	},
	'test06' => {
		'params' => {
			'element-tag' => ['div'],
			'element-cssselector' => ['nav#nav-id-1'],
			'&&' => 1, # intersection, nothing will be matched
		},
		'must-be-returned' => [],
		'must-not-be-returned' => ['header-id-1', 'nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
	},
	'test07' => {
		'params' => {
			'element-tag' => ['nav'],
			'element-cssselector' => ['nav#nav-id-1'],
			'&&' => 1, # intersection
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
	},
	# this will contain an empty id ('')
	'test08' => {
		'params' => {
			'element-tag' => ['nav'],
			'element-cssselector' => ['nav#nav-id-1'],
			'&&' => 1, # intersection
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
	},
	# this will have the empty id replaced with 'abc_0'
	'test09' => {
		'params' => {
			'element-tag' => ['nav'],
			'element-cssselector' => ['nav#nav-id-1'],
			'&&' => 1, # intersection
			'insert-id-if-none' => 'abc',
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2', 'abc_0'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
	},
	# this will contain duplicates
	'test10' => {
		'params' => {
			'element-tag' => ['div'],
			'element-id' => ['div-id-1'],
			'||' => 1, # union
		},
		'must-be-returned' => ['div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
		'must-not-be-returned' => ['header-id-1', 'nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2'],
		'must-have-duplicates' => 1,
	},
	# this will have the empty id replaced with 'abc_0' and therefore duplicates will be removed
	'test11' => {
		'params' => {
			'element-tag' => ['div'],
			'element-id' => ['div-id-1'],
			'||' => 1, # union
			'insert-id-if-none' => 'abc',
		},
		'must-be-returned' => ['div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
		'must-not-be-returned' => ['header-id-1', 'nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2', 'abc_0'],
		'must-have-duplicates' => 0,
	},
	# execute a callback
	'test20' => {
		'params' => {
			'element-tag' => ['nav'],
			'element-cssselector' => ['nav#nav-id-1'],
			'&&' => 1, # intersection
			'insert-id-if-none' => 'abc',
			'element-information-from-matched' => <<'EOJ',
// return anything but make sure you also include 'id' because tests need it
return {"blah" : htmlElement.tagName, "blih" : htmlElement.hasAttribute("role") ? htmlElement.getAttribute("role") : "<no role>", "id" : htmlElement.id};
EOJ
			'find-cb-on-matched' => [
			  {
			    'code' => 'console.log("find-cb-on-matched() : called on element \'"+htmlElement+"\' with tag \'"+htmlElement.tagName+"\' and id \'"+htmlElement.id+"\' ..."); return 1;',
			    'name' => 'func11'
			  },
			  {
			    'code' => 'console.log("find-cb-on-matched() : called on element \'"+htmlElement+"\' with tag \'"+htmlElement.tagName+"\' and id \'"+htmlElement.id+"\' ..."); return 1;',
			    'name' => 'func22'
			  },
			],
			#'js-outfile' => 'output.js'
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2', 'abc_0'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
		'keys-in-found' => ['blah', 'blih'],
	},
	# execute a callback for both levels
	'test21' => {
		'params' => {
			'element-tag' => ['nav'],
			'element-cssselector' => ['nav#nav-id-1'],
			'&&' => 1, # intersection
			'insert-id-if-none' => 'abc',
			'find-cb-on-matched' => [
			  {
			    'code' => 'console.log("find-cb-on-matched() : called on element \'"+htmlElement+"\' with tag \'"+htmlElement.tagName+"\' and id \'"+htmlElement.id+"\' ..."); return 1;',
			    'name' => 'func11'
			  },
			  {
			    'code' => 'console.log("find-cb-on-matched() : called on element \'"+htmlElement+"\' with tag \'"+htmlElement.tagName+"\' and id \'"+htmlElement.id+"\' ..."); return 1;',
			    'name' => 'func22'
			  },
			],
			'find-cb-on-matched-and-their-children' => [
			  {
			    'code' => 'console.log("find-cb-on-matched-and-their-children() : called on element \'"+htmlElement+"\' with tag \'"+htmlElement.tagName+"\' and id \'"+htmlElement.id+"\' ..."); return 1;',
			    'name' => 'func1'
			  },
			  {
			    'code' => 'console.log("find-cb-on-matched-and-their-children() : called on element \'"+htmlElement+"\' with tag \'"+htmlElement.tagName+"\' and id \'"+htmlElement.id+"\' ..."); return 1;',
			    'name' => 'func2'
			  },
			],
		},
		'must-be-returned' => ['nav-id-1', 'li-id-1', 'span-id-1', 'li-id-2', 'span-id-2', 'abc_0'],
		'must-not-be-returned' => ['header-id-1', 'div-id-1', 'div-id-1-1', 'div-id-2', 'div-id-2-1'],
	},
);

for my $tk (sort keys %tests){
	#next unless $tk =~ /-exception$/;
	diag "doing test '${tk}' ...";
	my $retmech = $mech_obj->get($URL);
	ok(defined($retmech), "mech_obj->get() : called.") or BAIL_OUT("test '${tk}' : failed to get() url '$URL'");
	$mech_obj->sleep(1); # let it settle
	my $tv = $tests{$tk};
	my $ret = find({
		'mech-obj' => $mech_obj,
		'js-outfile' => $js_outfile_tmp,
		%{ $tv->{'params'} }
	});
	ok(defined($ret), 'find()'." : test '${tk}' : called with these parameters: ".perl2dump($tv->{'params'})) or BAIL_OUT("test '${tk}' : failed.");

	is(ref($ret), 'HASH', 'find()'." : test '${tk}' : called and got defined returned value which is a HASHref.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	ok(exists($ret->{'status'}), 'find()'." : test '${tk}' : called and returned value contains key 'status'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	# some tests must throw an exception (there name must end in '-exception')
	if( $tk =~ /-exception$/ ){
		ok($ret->{'status'}<0, 'find()'." : test '${tk}' : called and returned value contains key 'status' which is ".$ret->{'status'}." < 0 (meaning an exception was thrown as expected).") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		next; # skip the rest, we got an expected exception all is doomed
	} else {
		ok($ret->{'status'}>=0, 'find()'." : test '${tk}' : called and returned value contains key 'status' which is ".$ret->{'status'}." >= 0 (meaning success).") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	}
	ok(exists($ret->{'found'}), 'find()'." : test '${tk}' : called and returned value contains key 'found'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	ok(defined($ret->{'found'}), 'find()'." : test '${tk}' : called and returned value contains key 'found' which has a defined value.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	is(ref($ret->{'found'}), 'HASH', 'find()'." : test '${tk}' : called and returned value contains key 'found' which is an HASHref.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	my $found = $ret->{'found'};
	my $exists_element_inform = exists $tv->{'params'}->{'element-information-from-matched'};
	for my $aresname ('first-level', 'all-levels'){
		ok(exists($found->{$aresname}), 'find()'." : test '${tk}' : called and 'found' contains key '${aresname}'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		ok(defined($found->{$aresname}), 'find()'." : test '${tk}' : called and 'found' contains key '${aresname}' which has a defined value.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		is(ref($found->{$aresname}), 'ARRAY', 'find()'." : test '${tk}' : called and result contains key '${aresname}' which is an ARRAYref.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		# check that it contains the fields of our default info-extractor js code or some fields in case of user-specified
		for my $afl (@{ $found->{$aresname} }){
			is(ref($afl), 'HASH', 'find()'." : test '${tk}' : called and result contains key '${aresname}' which is an ARRAYref which contains a HASH.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
			ok(scalar(keys %$afl)>0, 'find()'." : test '${tk}' : called and result contains key '${aresname}' which is an ARRAYref which contains a HASH which it has at least one entry.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
			if( $exists_element_inform ){
				for my $ak (exists($tv->{'keys-in-found'}) ? @{ $tv->{'keys-in-found'} } : qw/tag id/){
					ok(exists($afl->{$ak}), 'find()'." : test '${tk}' : called and result contains key '${aresname}' which is an ARRAYref which contains a HASH which contains key '$ak'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
					ok(defined($afl->{$ak}), 'find()'." : test '${tk}' : called and result contains key '${aresname}' which is an ARRAYref which contains a HASH which contains key '$ak' which is defined.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
				}
			}
		}
	}

	my %returnedids = map { $_ => 1 } grep { not /^\s*$/ } map { $_->{'id'} } @{ $found->{'all-levels'} };
	# check that those which were supposed to be removed are in the returned results and vice versa
	my %theids = map { $_ => 1 } @{ $tv->{'must-be-returned'} };
	for my $anid (sort keys %theids){
		ok(exists($returnedids{$anid}), "test '${tk}' : element with id '$anid' was found in the returned results.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	}
	for my $anid (sort keys %returnedids){
		ok(exists($theids{$anid}), "test '${tk}' : element with id '$anid' of the returned results is in the list of expected ids.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	}
	# now check that those which were supposed not to be removed are not in the returned results and vice versa
	%theids = map { $_ => 1 } @{ $tv->{'must-not-be-returned'} };
	for my $anid (sort keys %theids){
		ok(! exists($returnedids{$anid}), "test '${tk}' : element with id '$anid' was not found in the returned results.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	}
	for my $anid (sort keys %returnedids){
		ok(! exists($theids{$anid}), "test '${tk}' : element with id '$anid' of the returned results is not in the list of expected ids.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	}

	# check if there are duplicates if not supposed to be
	if( exists($tv->{'must-have-duplicates'}) ){
		my %someids =  map { $_ => 1 } map { $_->{'id'} } @{ $found->{'all-levels'} };
		my $has_dups = scalar(keys %someids) < scalar(@{ $found->{'all-levels'} });
		%someids =  map { $_ => 1 } map { $_->{'id'} } @{ $found->{'first-level'} };
		$has_dups ||= scalar(keys %someids) < scalar(@{ $found->{'first-level'} });
		is($tv->{'must-have-duplicates'}, $has_dups ? 1 : 0, "Returned results must ".($tv->{'must-have-duplicates'}==1?"":"not ")."have duplicates.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
	}

	# check return of the callbacks if any
	for my $acbname (@known_callbacks){
		next unless exists($tv->{'params'}->{$acbname}) && defined($tv->{'params'}->{$acbname});
		my $TV = $tv->{'params'}->{$acbname};

		# we must have a 'cb-results' in the returned value which must contain
		# an array of results (one item for each html element found)
		# under key $acbname (e.g. 'find-cb-on-matched' etc.)
		ok(exists($ret->{'cb-results'}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		ok(defined($ret->{'cb-results'}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results' and it is defined.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		ok(exists($ret->{'cb-results'}->{$acbname}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'->$acbname.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		ok(defined($ret->{'cb-results'}->{$acbname}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'->$acbname and it is defined.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		is(ref($ret->{'cb-results'}->{$acbname}), 'ARRAY', 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'->$acbname and it is an ARRAY.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");

		# and now under it we must have an array for each function callback we declared
		# and that array must have a size of as many html elements were returned
		# and each item of the array must contain keys 'result' and 'name' (which is the func name declared)
		is(scalar(@{$ret->{'cb-results'}->{$acbname}}), scalar(@{$TV}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'->$acbname and it is an ARRAY which has exactly as many items as there were callback functions for this specific cb type.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
		for(my $i=scalar(@{$ret->{'cb-results'}->{$acbname}});$i-->0;){
			my $ares1 = $ret->{'cb-results'}->{$acbname}->[$i];
			my $funcdata = $TV->[$i];
			if( $acbname eq 'find-cb-on-matched' ){
				is(scalar(@$ares1), scalar(@{$found->{'first-level'}}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'->$acbname and it is an ARRAY which has exactly as many items as the HTML elements matched (first-level).") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
			} else {
				is(scalar(@$ares1), scalar(@{$found->{'all-levels'}}), 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned value contains key 'cb-results'->$acbname and it is an ARRAY which has exactly as many items as the HTML elements matched (all-levels).") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
			}
			for my $ares2 (@$ares1){
				is($ares2->{'name'}, $funcdata->{'name'}, 'find()'." : test '${tk}' : called with a '${acbname}' callback and verified function name it is as it was declared '".$funcdata->{'name'}."'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
				is($ares2->{'result'}, 1, 'find()'." : test '${tk}' : called with a '${acbname}' callback and returned result is '1'.") or BAIL_OUT(perl2dump($ret)."test '${tk}' : failed, above is what it was returned from the call to find()");
			}
		}
	}
}

diag "temp dir: $tmpdir ..." if exists($ENV{'PERL_TEST_TEMPDIR_TINY_NOCLEANUP'}) && $ENV{'PERL_TEST_TEMPDIR_TINY_NOCLEANUP'}>0;

# END
done_testing();
