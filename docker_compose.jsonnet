function(config, keydir, specdir, publicKeys, datadir, artifacts, emptyBuild, rootMounts)

local
	containerBase = {
		build: emptyBuild,
		volumes: [
			'/%s:/%s' % [v, v],
			for v in rootMounts
		],
		networks: ['chainnet'],
	},
	commandList(list) = [
		'sh', '-c', std.join(' && \\\n', list) + '\n'
	],
	libp2pPort = 30333,
	merge(arr) = std.foldl(function(acc, v) acc + v, arr, {}),
;

std.manifestYamlDoc({
	version: '3.4',
	services: {
		['relay-%s-init-key' % node.name]: containerBase {
			volumes+: [
				'%s/relay-%s:/chain' % [datadir, node.name],
				'%s/relay.json:/chain.json' % [specdir],
			] + [
				'%s/relay-%s-%s:/keys/%s' % [keydir, node.name, type, type]
				for [type, ?] in node.requiredKeys
				if type[0] != '_'
			],
			command: commandList([
				'%s key insert --chain=/chain.json --base-path=/chain --scheme=%s --key-type=%s --suri=/keys/%s' % [
					node.keybin,
					scheme,
					type,
					type,
				],
				for [type, scheme] in node.requiredKeys
				if type[0] != '_'
			]),
		},
		for node in config.relay.nodes
	} + {
		['relay-%s' % node.name]: containerBase {
			depends_on: {
				['relay-%s-init-key' % node.name]: {
					condition: 'service_completed_successfully',
				},
			},
			volumes+: [
				'%s/relay-%s:/chain' % [datadir, node.name],
				'%s/relay.json:/chain.json' % [specdir],
				'%s/relay-%s-node:/keys/node' % [keydir, node.name]
			] + [
				'%s/relay-%s-%s:/keys/%s' % [keydir, node.name, type, type]
				for [type, ?] in node.requiredKeys
				if type[0] != '_'
			],
			[if 'ports' in node then 'ports']: [
				'%s:9944' % node.ports.ws,
				'%s:9933' % node.ports.http,
			],
			expose: [libp2pPort + ''],
			command: [
				node.bin,
				'--node-key-file=/keys/node',
				'--chain=/chain.json',
				'--base-path=/chain',
				'--validator',
				'--no-mdns',
				'--no-private-ipv4',
				'--no-hardware-benchmarks',
				'--enable-log-reloading',
				'--detailed-log-output',
				'--unsafe-rpc-external',
				'--unsafe-ws-external',
				'--rpc-cors=all',
				//'-ldebug,netlink_proto=info,wasmtime_cranelift=info,wasm-heap=info,trie-cache=info,wasm_overrides=info,multistream_select=info,libp2p_core=info,libp2p_swarm=info,libp2p_ping=info,trust_dns_resolver=info,libp2p_tcp=info,libp2p_dns=info,sub-libp2p=info',
			] + std.join([], [
            local multiaddr = '/dns/relay-%(name)s/tcp/%(libp2pPort)s/p2p/%(peerId)s' %
				({
					name: bootnode.name,
					libp2pPort: libp2pPort,
					peerId: publicKeys['relay-%s-node' % bootnode.name],
				}); [
              '--bootnodes=' + multiaddr,
              '--reserved-nodes=' + multiaddr,
            ]
            for bootnode in config.relay.nodes
            if node.name != bootnode.name
			]),
		},
		for node in config.relay.nodes
	} + merge([
		({
			['para-%s-artifacts' % parachain.name]: containerBase {
				volumes+: [
					'%s/para-%s.json:/chain.json' % [specdir, parachain.name],
					'%s/para-%s:/artifacts' % [artifacts, parachain.name],
				],
				command: commandList([
					'%s export-genesis-state --chain=/chain.json > /artifacts/genesis' % parachain.bin,
					'%s export-genesis-wasm --chain=/chain.json > /artifacts/genesis.wasm' % parachain.bin,
				]),
			},
		} + {
			['para-%s-%s-init-key' % [parachain.name, node.name]]: containerBase {
				volumes+: [
					'%s/para-%s-%s:/chain' % [datadir, parachain.name, node.name],
					'%s/para-%s.json:/chain.json' % [specdir, parachain.name],
				] + [
					'%s/para-%s-%s-%s:/keys/%s' % [keydir, parachain.name, node.name, type, type]
					for [type, ?] in node.requiredKeys
					if type[0] != '_'
				],
				command: commandList([
					'%s key insert --chain=/chain.json --base-path=/chain --scheme=%s --key-type=%s --suri=/keys/%s' % [
						node.keybin,
						scheme,
						type,
						type,
					],
					for [type, scheme] in node.requiredKeys
					if type[0] != '_'
				]),
			},
			for node in parachain.nodes
		} + {
			['para-%s-%s' % [parachain.name, node.name]]: containerBase {
				depends_on: {
					['para-%s-%s-init-key' % [parachain.name, node.name]]: {
						condition: 'service_completed_successfully',
					},
				},
				volumes+: [
					'%s/para-%s-%s:/chain' % [datadir, parachain.name, node.name],
					'%s/para-%s.json:/chain.json' % [specdir, parachain.name],
					'%s/para-%s-%s-relay:/relay-chain' % [datadir, parachain.name, node.name],
					'%s/relay.json:/relay-chain.json' % [specdir],
					'%s/para-%s-%s-node:/keys/node' % [keydir, parachain.name, node.name]
				] + [
					'%s/para-%s-%s-%s:/keys/%s' % [keydir, parachain.name, node.name, type, type]
					for [type, ?] in node.requiredKeys
					if type[0] != '_'
				],
				[if 'ports' in node then 'ports']: [
					'%s:9944' % node.ports.ws,
					'%s:9933' % node.ports.http,
				],
				expose: [libp2pPort + ''],
				command: [
					node.bin,
					'--node-key-file=/keys/node',
					'--chain=/chain.json',
					'--base-path=/chain',
					'--validator',
					'--no-mdns',
					'--no-private-ipv4',
					'--no-hardware-benchmarks',
					'--enable-log-reloading',
					'--detailed-log-output',
					'--unsafe-rpc-external',
					'--unsafe-ws-external',
					'--rpc-cors=all',
					//'-ldebug,netlink_proto=info,wasmtime_cranelift=info,wasm-heap=info,trie-cache=info,wasm_overrides=info,multistream_select=info,libp2p_core=info,libp2p_swarm=info,libp2p_ping=info,trust_dns_resolver=info,libp2p_tcp=info,libp2p_dns=info,sub-libp2p=info',
				] + std.join([], [
		         local multiaddr = '/dns/para-%(para)s-%(name)s/tcp/%(libp2pPort)s/p2p/%(peerId)s' % {
						para: parachain.name,
						name: bootnode.name,
						libp2pPort: libp2pPort,
						peerId: publicKeys['para-%s-%s-node' % [parachain.name, bootnode.name]],
					};
					[
	              '--bootnodes=' + multiaddr,
	              '--reserved-nodes=' + multiaddr,
		         ]
					for bootnode in parachain.nodes
				   if node.name != bootnode.name
				]) + [
					'--',
					'--chain=/relay-chain.json',
					'--base-path=/relay-chain',
				] + std.join([], [
				   local multiaddr = '/dns/relay-%(name)s/tcp/%(libp2pPort)s/p2p/%(peerId)s' %
					({
						name: bootnode.name,
						libp2pPort: libp2pPort,
						peerId: publicKeys['relay-%s-node' % bootnode.name],
					}); [
				     '--bootnodes=' + multiaddr,
				     '--reserved-nodes=' + multiaddr,
				   ]
				   for bootnode in config.relay.nodes
				   if node.name != bootnode.name
				]),
			},
			for node in parachain.nodes
		})
		for [?, parachain] in config.parachains
	]),
	networks: {
		chainnet: {
			driver: 'bridge',
		},
	},
}, quote_keys = false, preserve_order = true)
