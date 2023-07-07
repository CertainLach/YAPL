use feature 'signatures';
use warnings;
use strict;

use File::Path qw(make_path);
use File::Temp qw(tempfile);
use File::Spec qw(rel2abs abs2rel);
use JSON::PP qw(decode_json encode_json);
use Data::Dumper;
use IPC::Run qw(run);
use String::Util qw(trim);

my $jsonnet = '/home/lach/unqdev/chainql/target/release/chainql';
my $polkadot = '/home/lach/unqdev/polkadot/target/release/polkadot';

sub jsonnet_do {
	my ($code, $tla, $tla_raw) = @_;
	my @tla_args;
	while (my ($key, $value) = each %$tla) {
		my $json_value=encode_json($value);
		push @tla_args, "--tla-code", "$key=$json_value";
	}
	while (my ($key, $value) = each %$tla_raw) {
		push @tla_args, "--tla-code", "$key=$value";
	}

	my $output;
	my $error;
	run([$jsonnet, @tla_args, '-e', $code], \undef, \$output, \$error);
	if ($error) {
		die "Failed to execute jsonnet code: $error";
	}
	return decode_json($output);
}
sub generate_key {
	my ($scheme) = @_;

	my $output;
	my $error;
	run([$polkadot, 'key', 'generate', "--scheme=$scheme", '--output-type=json', '--words=24'], \undef, \$output, \$error);
	if ($error) {
		die "Failed to generate key: $error";
	}
	return decode_json($output);
}
sub generate_node_key {
	my $output;
	my $error;
	run([$polkadot, 'key', 'generate-node-key', '--bin'], \undef, \$output, \$error);

	my %result = (
		'identity' => trim($error),
		'key' => $output,
	);
	return \%result;
}

sub generate_config_secrets {
	my ($dir, $config) = @_;

	make_path $dir;
	

	my %public_h = ();
	my $public = \%public_h;
	my $had_updated = 0;
	if (-e "$dir/public.json") {
		print "✅ Loaded existing keys\n";
		open(my $fh, "<", "$dir/public.json");
		local $/;
		my $public_str = <$fh>;

		$public = decode_json($public_str);
	}

	my @nodes = @{jsonnet_do '
		function(config)

		local flatten(arr) = std.foldl(function(v, acc) acc + v, arr, []);

		["relay-" + node.name + "-node" for node in config.relay.nodes] +
		flatten([
			[
				"para-" + parachain.name + "-" + node.name + "-node" for node in parachain.nodes
			]
			for parachain in std.objectValues(config.parachains)
		])
	', {}, {'config' => $config}};

	print "🚧 Generating libp2p keys\n";
	foreach my $node (@nodes) {
		my $key = generate_node_key;
		my $identity = $key->{identity};
		my $private = $key->{key};

		if (-e "$dir/$node") {
			next;
		}

		$had_updated = 1;
		$public->{$node} = $identity;

		print "  🛂 $node = $identity\n";
		open(my $fh, '>', "$dir/$node") or die "Failed to open keyfile";
		print $fh $private;
		close $fh;
	}

	my @keys = @{jsonnet_do '
		function(config)

		local flatten(arr) = std.foldl(function(v, acc) acc + v, arr, []);
		[
			{
				name: "relay-" + node.name + "-" + key,
				scheme: scheme,
				keyType: key,
			}
			for node in config.relay.nodes
			for [key, scheme] in node.requiredKeys
		] +
		flatten([
			[
				{
					name: "para-" + parachain.name + "-" + node.name + "-" + key,
					scheme: scheme,
					keyType: key,
				}
				for node in parachain.nodes
				for [key, scheme] in node.requiredKeys
			]
			for parachain in std.objectValues(config.parachains)
		])
	', {}, {'config' => $config}};

	my $keyIcons = {
		'aura' => "🔮",
	};

	print "🚧 Generating subsystem keys\n";
	foreach my $node (@keys) {
		my $key = generate_key($node->{scheme});
		my $name = $node->{name};
		my $ss58 = $key->{ss58PublicKey};
		my $keyType = $node->{keyType};

		if (-e "$dir/$name") {
			next;
		}

		$had_updated = 1;
		$public->{$name} = $ss58;

		my $icon = $keyIcons->{$keyType} // "🗝️";
		print "  $icon $name = $ss58\n";
		open(my $fh, '>', "$dir/$name") or die "Failed to open keyfile";
	
		print $fh $key->{secretPhrase};
		close $fh;
	}

	print "✅ Success!\n";

	open(my $ch, ">", "$dir/public.json");
	print $ch encode_json($public);
	return ($public, $had_updated);
}

sub generate_specs {
	my ($dir, $config, $public_keys, $regenerate) = @_;

	make_path $dir;

	my @specs = @{jsonnet_do '
		function(config)

		[
			{
				attr: "relay",
				name: "relay",
				bin: config.relay.bin,
				chain: config.relay.chain,
			}
		] + [
			{
				attr: "parachains." + parachain.name,
				name: "para-" + parachain.name,
				bin: parachain.bin,
				chain: parachain.chain,
			}
			for parachain in std.objectValues(config.parachains)
		]
	', {}, {'config' => $config}};

	foreach my $spec (@specs) {
		my $bin = $spec->{bin};
		my $chain = $spec->{chain};
		my $attr = $spec->{attr};
		my $name = $spec->{name};

		if (-e "$dir/$name.json" and !$regenerate) {
			print "✅ Assuming spec $name is unchanged\n";
			next;
		}

		print "🚧🚧🚧 Generating spec $name 🚧🚧🚧\n";
	
		print "🚧 Generating json spec\n";
		my $spec_txt = `$bin build-spec --chain=$chain`;
		# Ensure built
		decode_json($spec_txt);

		my ($spec_fh, $spec_file) = tempfile();
		print $spec_fh $spec_txt;

		print "🚧 Patching json spec at $spec_file\n";
		my %patched_spec = %{jsonnet_do '
			function(attr, config, spec, publicKeys)

			local get(o, p) = std.foldl(function(o, k) o[k], std.split(p, "."), o);

			get(config, attr).modify(spec, publicKeys)
		', {'attr' => $attr, 'publicKeys' => $public_keys}, {'config' => $config, 'spec' => "import '$spec_file'"}};
		my $patched_spec_txt = encode_json(\%patched_spec);

		my ($patched_spec_fh, $patched_spec_file) = tempfile();
		print $patched_spec_fh $patched_spec_txt;

		print "🚧 Converting json spec at $patched_spec_file to raw spec\n";
		my $raw_spec_txt = `$bin build-spec --raw --chain=$patched_spec_file`;
		# Ensure built
		decode_json($raw_spec_txt);

		my ($raw_spec_fh, $raw_spec_file) = tempfile();
		print $raw_spec_fh $raw_spec_txt;

		print "🚧 Patching raw spec at $raw_spec_file\n";
		my %patched_raw_spec = %{jsonnet_do '
			function(attr, config, rawSpec)

			local get(o, p) = std.foldl(function(o, k) o[k], std.split(p, "."), o);

			get(config, attr).modifyRaw(rawSpec)
		', {'attr' => $attr}, {'config' => $config, 'rawSpec' => "import '$raw_spec_file'"}};
		my $patched_raw_spec_txt = encode_json(\%patched_raw_spec);

		open(my $fh, '>', "$dir/$name.json") or die "Failed to open output spec";
		print $fh $patched_raw_spec_txt;

		print "✅✅✅ Success! ✅✅✅\n";
	}
}

sub generate_dockercompose_project {
	my ($dir, $config, $keydir, $specdir, $datadir, $artifacts, $public_keys) = @_;

	make_path $dir;
	my $fulldir = File::Spec->rel2abs($dir);
	my $fullkey = File::Spec->rel2abs($keydir);
	my $fullspec = File::Spec->rel2abs($specdir);
	my $fulldata = File::Spec->rel2abs($datadir);
	my $fullempty = File::Spec->rel2abs('empty');
	my $fullartifacts = File::Spec->rel2abs($artifacts);
	$keydir = File::Spec->abs2rel($fullkey, $fulldir);
	$specdir = File::Spec->abs2rel($fullspec, $fulldir);
	$datadir = File::Spec->abs2rel($fulldata, $fulldir);
	$artifacts = File::Spec->abs2rel($fullartifacts, $fulldir);
	my $empty = File::Spec->abs2rel($fullempty, $fulldir);

	my $compose = jsonnet_do '
		import "docker_compose.jsonnet"
	', {
		'keydir' => $keydir,
		'specdir' => $specdir,
		'datadir' => $datadir,
		'emptyBuild' => $empty,
		'artifacts' => $artifacts,
		'publicKeys' => $public_keys,
		'rootMounts' => [split(/\s/, `ls /`)],
	}, {'config' => $config};

	open(my $fh, ">", "$dir/docker-compose.yaml");
	print $fh $compose;
	print "✅ Generated docker-compose\n";
}

my ($public_keys, $updated) = generate_config_secrets('testkeys', 'import "config.jsonnet"');
if ($updated) {
	print "⚠️ Some of the keys were updated\n";
}
generate_specs('testspecs', 'import "config.jsonnet"', $public_keys, $updated);
generate_dockercompose_project('testcompose', 'import "config.jsonnet"', 'testkeys', 'testspecs', 'testdata', 'testartifacts', $public_keys);
# start_dockercompose('testcompose');
# reserve_para_id
# register_parathread
# upgrade_parathread
# wait_for_parachain_to_start_working
# rollup_nodes_upgrade
# wait_for_upgraded_nodes_to_produce_block
# finish_nodes_upgrade
# authorize_upgrade
# enact_authorized_upgrade
# wait_for_upgrade

