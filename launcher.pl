use feature 'signatures';
use warnings;
use strict;

use File::Path qw(make_path);
use File::Temp qw(tempfile);
use JSON::PP qw(decode_json);
use Data::Dumper;

sub encode_json {
	my ($value) = @_;
	return JSON::PP->new()->pretty(1)->encode($value);
}

sub say {
	print(@_, "\n")
}

my $jsonnet = 'jrsonnet';
sub confprop {
	my ($key) = @_;
	my $value = `$jsonnet -e "(import 'config.jsonnet').$key"` or die "jrsonnet failed";
	return decode_json($value);
}
sub conflen {
	my ($key) = @_;
	my $value = `$jsonnet -e "std.length((import 'config.jsonnet').$key)"` or die "jrsonnet failed";
	return decode_json($value);
}
sub confcalljson {
	my ($key, $data) = @_;
	my ($fh, $filename) = tempfile();
	print $fh encode_json($data);
	my $value = `$jsonnet --tla-code=data='std.parseJson(importstr"$filename")' --exec "function(data) ((import 'config.jsonnet').$key(data))"`;
	close($fh);
	return decode_json($value);
}

my $subkey = confprop 'subkey';
sub seedToSs58 {
	my ($seed) = @_;
	my $data = `$subkey inspect --output-type=json $seed` or die "subkey failed";
	my $datajson = decode_json($data);
	return $datajson->{ss58PublicKey};
}
sub seedToSs58Ed25519 {
	my ($seed) = @_;
	my $data = `$subkey inspect --scheme=ed25519 --output-type=json $seed` or die "subkey failed";
	my $datajson = decode_json($data);
	return $datajson->{ss58PublicKey};
}
sub seedToSs58Ecdsa {
	my ($seed) = @_;
	my $data = `$subkey inspect --scheme=ecdsa --output-type=json $seed` or die "subkey failed";
	my $datajson = decode_json($data);
	return $datajson->{ss58PublicKey};
}
sub nodeKeyToPeerId {
	my ($nodeKey) = @_;
	my $data = `echo $nodeKey | $subkey inspect-node-key` or die "subkey failed";
	chomp($data);
	return $data;
}

sub mkspec {
	my ($bin, $initial, $ty, $patcher) = @_;
	my $spec = `$bin build-spec --chain $initial`;
	my $specjson = confcalljson("$ty.rawModify", decode_json($spec));

	$specjson->{telemetryEndpoints} = [];
	$specjson->{bootNodes} = [];
	$patcher->($specjson);

	my ($fh, $filename) = tempfile();
	print $fh encode_json($specjson);
	my $rawspec = `$bin build-spec --raw --chain=$filename`;
	close($fh);
	my $rawspecjson = decode_json($rawspec);
	$rawspecjson->{bootNodes} = [];
	return $rawspecjson;
}

my $relayNodes = confprop('relay.nodes');
foreach my $node (@$relayNodes) {
	$node->{peerId} = nodeKeyToPeerId($node->{key});
}

my $relaySpecData = mkspec(confprop('relay.bin'), confprop('relay.spec'), 'relay', sub {
	my ($spec) = @_;
	$spec->{genesis}->{runtime}->{runtime_genesis_config}->{sudo}->{key} = seedToSs58(confprop 'relay.sudo');
	my @extrabalance = (
		confprop('relay.sudo'),
		5000000000000000000
	);
	my @balances = (
		\@extrabalance	
	);
	$spec->{genesis}->{runtime}->{runtime_genesis_config}->{balances}->{balances} = \@balances;

	# TODO: Those modifications should be performed in rawModify
	my @sessionkeys = ();
	foreach my $node (@$relayNodes) {
		my $seed = $node->{seed};
		my $stash = seedToSs58("$seed//stash");
		my $sr = seedToSs58($seed);
		my $ed25519 = seedToSs58Ed25519($seed);
		my $ec = seedToSs58Ecdsa($seed);
		my @sessionkey = (
			$stash,
			$stash,
			{
				grandpa => $ed25519,
				babe => $sr,
				im_online => $sr,
				parachain_validator => $sr,
				authority_discovery => $sr,
				para_validator => $sr,
				para_assignment => $sr,
				beefy => $ec,
			},
		);
		push(@sessionkeys, (\@sessionkey));
		sub seed {
			my ($ty, $uri, $sch) = @_;
			return {
				ty => $ty,
				sch => $sch,
				uri => $uri,
			};
		}
		$node->{seeds} = [
			seed("gran", $seed, "ed25519"),
			seed("babe", $seed, "sr25519"),
			seed("imon", $seed, "sr25519"),
			seed("para", $seed, "sr25519"),
			seed("asgn", $seed, "sr25519"),
			seed("audi", $seed, "sr25519"),
			seed("beef", $seed, "ecdsa"),
		];
	}
	$spec->{genesis}->{runtime}->{runtime_genesis_config}->{session}->{keys} = \@sessionkeys;
});

my @parachains = ();
foreach my $id (1..conflen('parachains')) {
	my $key = "parachains[$id - 1]";
	my $name = confprop("$key.name");

	if (!confprop("$key.enabled")) {
		say "para $name disabled";
		next;
	}

	my $paraNodes = confprop("$key.nodes");
	foreach my $node (@$paraNodes) {
		$node->{peerId} = nodeKeyToPeerId($node->{key});
	}

	# TODO: Those modifications should be performed in rawModify
	my $parachainSpecData = mkspec(confprop("$key.bin"), confprop("$key.spec"), "$key", sub {
		my ($spec) = @_;
		$spec->{genesis}->{runtime}->{sudo}->{key} = seedToSs58(confprop "$key.sudo");
		my @extrabalance = (
			confprop("$key.sudo"),
			5000000000000000000
		);
		my @balances = (
			\@extrabalance	
		);
		$spec->{genesis}->{runtime}->{balances}->{balances} = \@balances;

		my @sessionkeys = ();
		my @invulnerables = ();
		foreach my $node (@$paraNodes) {
			my $seed = $node->{seed};
			my $sr = seedToSs58($seed);
			my @sessionkey = (
				$sr,
				$sr,
				{
					aura => $sr,
				},
			);
			push(@invulnerables, $sr);
			push(@sessionkeys, (\@sessionkey));
			sub seed {
				my ($ty, $uri, $sch) = @_;
				return {
					ty => $ty,
					sch => $sch,
					uri => $uri,
				};
			}
			$node->{seeds} = [
				seed("aura", $seed, "sr25519"),
			];
		}
		$spec->{genesis}->{runtime}->{session}->{keys} = \@sessionkeys;
		$spec->{genesis}->{runtime}->{collatorSelection}->{invulnerables} = \@invulnerables;
	});

	push(@parachains, {
		bin => confprop("$key.bin"),
		ports => confprop("$key.ports"),
		extraArgs => confprop("$key.extraArgs"),
		name => $name,
		specData => $parachainSpecData,
		nodes => $paraNodes,
	});
}

my $spec = encode_json({
	rootMounts => [split(/\s/, `ls /`)],
	relay => {
		specData => $relaySpecData,
		bin => confprop('relay.bin'),
		ports => confprop('relay.ports'),
		nodes => $relayNodes,
	},
	parachains => \@parachains,
});
open(my $specfile, ">", "spec.json");
print $specfile $spec;
close($specfile);

`$jsonnet out.jsonnet -Scmout`;

`cd out && docker compose up --remove-orphans`;