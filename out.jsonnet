local spec = import './spec.json';

local
  joinObjects(arr) = std.foldl(function(acc, item) acc + item, arr, {}),
  addIdxs(arr) = std.mapWithIndex(function(i, a) a {id:i}, arr)
;

local
  volumes = ['/%s:/%s' % [v, v] for v in spec.rootMounts],
  containerBase = {
    build: '../empty',
    volumes: volumes,
    networks: ['chainnet'],
  },
  libp2pPort = 30333,
;

// {
//   ['keys/relay-%s' % node.name]: node.key
//   for node in spec.relay.nodes
// } +
{
  ['specs/para-%s.json' % parachain.name]: std.manifestJsonEx(parachain.specData, preserve_order=true, indent='  '),
  for parachain in spec.parachains
} +
{
  'specs/relay.json': std.manifestJsonEx(spec.relay.specData, preserve_order=true, indent='  '),
  'compose.yaml': std.manifestYamlDoc({
    services: 
      {
        ['para-%s-export-genesis' % parachain.name]: containerBase {
          volumes+: [
            './data-para-%(para)s:/chain-data' % parachain.name,
            './specs/para-%s.json:/chain-spec.json' % parachain.name,
            // './keys/relay-%s:/chain-key' % node.name,
          ],
          command: [
            'sh',
            '-c',
            std.join(' && \\\n', [
              parachain.bin + " export-genesis-state --chain=/chain-spec.json > /chain-data/genesis-state",
              parachain.bin + " export-genesis-wasm --chain=/chain-spec.json > /chain-data/genesis-wasm",
            ]),
          ],
        }
        for parachain in spec.parachains
      }+
      joinObjects([{
        ['para-%(para)s-%(node)s-init-key' % {para: parachain.name, node: node.name}]: containerBase {
          volumes+: [
            './data-para-%(para)s-%(node)s:/chain-data' % {para: parachain.name, node: node.name},
            './specs/para-%s.json:/chain-spec.json' % parachain.name,
            // './keys/relay-%s:/chain-key' % node.name,
          ],
          command: [
            'sh',
            '-c',
            std.join(' && \\\n', std.map(function(data) parachain.bin + " key insert --chain=/chain-spec.json --base-path=/chain-data --scheme=%(sch)s --key-type=%(ty)s --suri=%(uri)s" % data, node.seeds)) + '\n'
          ],
        },
        ['para-%(para)s-%(node)s' % {para: parachain.name, node: node.name}]: containerBase {
          depends_on: {
            ['para-%(para)s-%(node)s-init-key' % {para: parachain.name, node: node.name}]: {
              condition: 'service_completed_successfully',
            }
          },
          expose: [libp2pPort+''],
          [if node.id == 0 then 'ports']: [
            '0.0.0.0:%d:9944' % parachain.ports.ws,
            '0.0.0.0:%d:9933' % parachain.ports.http,
          ],
          volumes+: [
            './data-para-%(para)s-%(node)s:/chain-data' % {para: parachain.name, node: node.name},
            './specs/para-%s.json:/chain-spec.json' % parachain.name,
            './data-para-%(para)s-%(node)s-relay:/relay-chain-data' % {para: parachain.name, node: node.name},
            './specs/relay.json:/relay-chain-spec.json',
            // './keys/relay-%s:/chain-key' % node.name,
          ],
          command: [
            parachain.bin,
            // TODO: Load from file, arguments are not secure
            '--node-key=' + node.key,
            '--chain=/chain-spec.json',
            '--base-path=/chain-data',
            '--collator',
            '--unsafe-rpc-external',
            '--unsafe-ws-external',
            '--rpc-cors=all',
            '--rpc-methods=unsafe',
            '--no-mdns',
            '--no-hardware-benchmarks',
            '--enable-log-reloading',
          ] + parachain.extraArgs + std.flattenArrays([
            local multiaddr = '/dns/para-%(paraName)s-%(name)s/tcp/%(libp2pPort)s/p2p/%(peerId)s' % (bootnode {
              libp2pPort: libp2pPort,
              paraName: parachain.name,
            }); [
              '--bootnodes=%s' % multiaddr,
              '--reserved-nodes=%s' % multiaddr,
            ],
            for bootnode in parachain.nodes
            if node.name != bootnode.name
          ]) + [
            '--',
            '--chain=/relay-chain-spec.json',
            '--base-path=/relay-chain-data',
          ] + std.flattenArrays([
            local multiaddr = '/dns/relay-%(name)s/tcp/%(libp2pPort)s/p2p/%(peerId)s' % (bootnode {
              libp2pPort: libp2pPort,
            }); [
              '--bootnodes=%s' % multiaddr,
              '--reserved-nodes=%s' % multiaddr,
            ],
            for bootnode in spec.relay.nodes
          ]),
        }
      }
      for parachain in spec.parachains
      for node in addIdxs(parachain.nodes)
    ]) + {
      ['relay-%s-init-key' % node.name]: containerBase {
        volumes+: [
          './data-relay-%s:/chain-data' % node.name,
          './specs/relay.json:/chain-spec.json',
          // './keys/relay-%s:/chain-key' % node.name,
        ],
        command: [
          'sh',
          '-c',
          std.join(' && \\\n', std.map(function(data) spec.relay.bin + " key insert --chain=/chain-spec.json --base-path=/chain-data --scheme=%(sch)s --key-type=%(ty)s --suri=%(uri)s" % data, node.seeds)) + '\n'
        ],
      },
      for node in spec.relay.nodes
    } + {
      ['relay-%s' % node.name]: containerBase {
        depends_on: {
          ['relay-%s-init-key' % node.name]: {
            condition: 'service_completed_successfully',
          }
        },
        expose: [libp2pPort+''],
        [if node.id == 0 then 'ports']: [
            '0.0.0.0:%d:9944' % spec.relay.ports.ws,
            '0.0.0.0:%d:9933' % spec.relay.ports.http,
        ],
        volumes+: [
          './data-relay-%s:/chain-data' % node.name,
          './specs/relay.json:/chain-spec.json',
          // './keys/relay-%s:/chain-key' % node.name,
        ],
        command: [
          spec.relay.bin,
          '--node-key=' + node.key,
          '--chain=/chain-spec.json',
          '--base-path=/chain-data',
          '--validator',
          '--unsafe-rpc-external',
          '--unsafe-ws-external',
          '--rpc-cors=all',
          '--rpc-methods=unsafe',
          '--no-mdns',
          '--no-hardware-benchmarks',
          '--enable-log-reloading',
        ] + std.flattenArrays([
          local multiaddr = '/dns/relay-%(name)s/tcp/%(libp2pPort)s/p2p/%(peerId)s' % (bootnode {
            libp2pPort: libp2pPort,
          }); [
            '--bootnodes=%s' % multiaddr,
            '--reserved-nodes=%s' % multiaddr,
          ],
          for bootnode in spec.relay.nodes
          if node.name != bootnode.name
        ]),
      }
      for node in addIdxs(spec.relay.nodes)
    },
    networks: {
      chainnet: {
        driver: 'bridge',
      }
    },
  }, quote_keys=false, preserve_order=true),
}
