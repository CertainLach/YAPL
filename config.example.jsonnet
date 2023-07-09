local
  account(name) = cql.ss58Encode(cql.sr25519Seed(name)),
  flatten(arr) = std.foldl(function(acc, v) acc + v, arr, []),
  merge(arr) = std.foldl(function(acc, v) acc + v, arr, {}),
;

local rawMixins = {
  // Some chains store genesis config at a different location
  genesis: error "unknown genesis structure",
  multi(mixins): merge(mixins),

  setSudo(address): $.genesis({
    sudo+: {
      key: address,
    },
  }),
  resetBalances: $.genesis({
    balances+: {
      balances: [],
    },
  }),
  giveBalance(address, amount): $.genesis({
    balances+: {
      balances+: [
        [address, amount],
      ],
    },
  }),
  setParaId(id): {
    para_id: id,
  } + $.genesis({
    parachainInfo+: { parachainId: id },
  }),
  clearTelemetryBootnodes: {
    chainType: 'Live',
    telemetryEndpoints: [],
    bootNodes: [],
    codeSubstitutes: {},
  },
  resetSessionKeys: $.genesis({
    session+: {
      keys: [],
    },
  }),
  addSessionKey(key): $.genesis({
    session+: {
      keys+: [key],
    },
  }),
  resetInvulnerables: $.genesis({
    collatorSelection+: {
      invulnerables: [],
    },
  }),
  addInvulnerable(key): $.genesis({
    collatorSelection+: {
      invulnerables+: [key],
    },
  }),
  resetStakingInvulnerables: $.genesis({
    staking+: {
      invulnerables: [],
    },
  }),
  addStakingInvulnerable(key): $.genesis({
    staking+: {
      invulnerables+: [key],
    },
  }),
  resetStakingStakers: $.genesis({
    staking+: {
      stakers: [],
    },
  }),
  addStakingStaker(key): $.genesis({
    staking+: {
      stakers+: [key],
    },
  }),
};
local mSane = rawMixins {
  genesis(mixin): {
    genesis+: {
      runtime+: if std.isArray(mixin) then $.multi(mixin) else mixin,
    },
  },
};
local mRococo = rawMixins {
  genesis(mixin): {
    genesis+: {
      runtime+: {
        runtime_genesis_config+: if std.isArray(mixin) then $.multi(mixin) else mixin,
      },
    },
  },
};

local relay = {
  bin: 'polkadot/target/release/polkadot',
  // rococo: spec
  chain: 'rococo-local',

  // rococo: use other mixins
  modify(spec, publicKeys): local m = mRococo; spec + m.multi([
    m.clearTelemetryBootnodes,
    m.setSudo(account('//Alice')),
    // m.resetBalances,
    // m.giveBalance(account('//Alice'), 1000000000000000000),
    
    m.resetSessionKeys,
    // rococo: disable staking
    // m.resetStakingInvulnerables,
    // m.resetStakingStakers,
  ]) + m.multi(std.join([], [
    local key(name) = publicKeys["relay-%s-%s" % [node.name, name]];
    [
      m.giveBalance(key('_stash'), 100000000000000000),
      m.addSessionKey([key('_stash'), key('_stash'), {
        grandpa: key('gran'),
        babe: key('babe'),
        im_online: key('imon'),
        authority_discovery: key('audi'),
        para_assignment: key('asgn'),
        para_validator: key('para'),
        // rococo: beefy is required
        beefy: key('beef'),
      }]),
      // rococo: disable staking
      // m.addStakingInvulnerable(key('_stash')),
      // m.addStakingStaker([key('_stash'), key('_account'), 
      //   100000000000000,
      //   'Validator',
      // ])
    ]
    for node in $.nodes
  ])),
  modifyRaw(spec): spec,

  nodes: [
    {
      name: name,
      bin: $.bin,
      keybin: $.bin,
      requiredKeys: {
        _stash: 'sr25519',
        _account: 'sr25519',

        gran: 'ed25519',
        babe: 'sr25519',
        imon: 'sr25519',
        para: 'sr25519',
        asgn: 'sr25519',
        audi: 'sr25519',
        // rococo: beefy is required
        beef: 'ecdsa',
      },
      [if name == 'freddie' then 'ports']: {
        ws: '127.0.0.1:9844',
        http: '127.0.0.1:9833',
      },
    } for name in ['freddie', 'venus', 'earth', 'mars', 'jupyter', 'saturn', 'uranus', 'neptune']
  ],
};

local unique = {
  name: 'unique',
  enabled: true,

  bin: 'unique-chain/target/release/unique-collator',
  chain: 'local',

  modify(spec, publicKeys): local m = mSane; spec + m.multi([
    m.clearTelemetryBootnodes,
    m.setSudo(account('//Alice')),
    m.resetBalances,
    m.giveBalance(account('//Alice'), 10000000000000000000),
    m.setParaId(2000),
    m.resetSessionKeys,
    m.resetInvulnerables,
  ]) + m.multi([
    local key = publicKeys["para-%s-%s-aura" % [$.name, node.name]];
    m.addSessionKey([key, key, { aura: key }])
    for node in $.nodes
  ]) + m.multi([
    local key = publicKeys["para-%s-%s-aura" % [$.name, node.name]];
    m.addInvulnerable(key),
    for node in $.nodes
  ]),
  modifyRaw(spec): spec,

  nodes: [
    {
      name: name,
      bin: $.bin,
      keybin: $.bin,
      requiredKeys: {
        aura: 'sr25519',
      },
      extraArgs: [
        '--state-pruning=archive',
        '--blocks-pruning=archive-canonical',
      ],
      [if name == 'ceres' then 'ports']: {
        ws: '127.0.0.1:9944',
        http: '127.0.0.1:9933',
      },
    } for name in [
      'ceres', 'ganymede', 'callisto', 'mimas', 'enceladus', 'tethys', 'dione', 'rhea', 'titan', 'iapetus',
      // MAX_COLLATORS = 10
      //'miranda', 'ariel', 'umbriel', 'titania', 'oberon', 'triton', 'pluto', 'charon', 'eris', 'dysnomia'
    ]
  ],
};

local parachains = [unique];

{
  relay: relay,

  parachains: {
    [para.name]: para,
    for para in parachains
    if para.enabled
  },
}
