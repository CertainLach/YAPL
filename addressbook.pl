use feature 'signatures';
use warnings;
use strict;

use JSON::PP qw(decode_json encode_json);
use IPC::Run qw(run);

my $jsonnet = '/home/lach/unqdev/chainql/target/release/chainql';

`$jsonnet addressbook.jsonnet -S | wl-copy`;
print "✅ Addressbook filler is copied to the clipboard\n";
