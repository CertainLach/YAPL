{
  subkey: '/absolute/path/to/polkadot/bin key',
  relay: {
    bin: '/absolute/path/to/polkadot/bin',
    spec: 'rococo-local',
    sudo: '5CtUqwhQdBypugUn6mVfUuQXEHt4qATcAXeBrqAfhcY1XTuc',
    ports: { http: 19933, ws: 19944 },

    rawModify(spec): spec { chainType: 'Live' },

    nodes: [
      { name: 'freddie', seed: '//Freddie', key: '108011f08f1a24312fad52429c5a03f3d1f869d08374df276e73f9c3ac83e32b' },
      { name: 'venus', seed: '//Venus', key: 'e404c4def79b7b372cf98735307d9f4c775747e54c861fae9205a9afefb40c11' },
      { name: 'earth', seed: '//Earth', key: '21e87b198662c9eb1614c5116de68fa3cb3c537aa44c4538efce7dff8a2cbe97' },
      { name: 'mars', seed: '//Mars', key: 'efde41638a69f04be87e86276de20a4470f1660805927f7cb21c00bc49ff519f' },
      { name: 'jupyter', seed: '//Jupyter', key: 'deef22b966f57d1b73516719297aa15708423dd150cf8d4ab89e690fc9dc033d' },
      { name: 'saturn', seed: '//Saturn', key: 'dc9abe74a57fdfa60ab2896f1a94c5f1d3655e6b540488e4462c4846a0ec06fc' },
      { name: 'uranus', seed: '//Uranus', key: '4d0242e87db7f77dcd90388799dba5867cb3cdee8112d38bf5e4d3354d9629f4' },
      { name: 'neptune', seed: '//Neptune', key: '60ebb182629ef77bc539d2fdc2717bda60d3eecc4ec1783ea1c46059e2b4fc3b' },
    ],
  },

  parachains: [
    {
      name: 'collator',
      enabled: true,
      bin: '/absolute/path/to/collator',
      spec: 'local',
      sudo: '5CtUqwhQdBypugUn6mVfUuQXEHt4qATcAXeBrqAfhcY1XTuc',
      ports: { http: 29933, ws: 29944 },

      rawModify(spec): spec {
        relay_chain: 'assert-unused',
        chainType: 'Live',
        para_id: 2000,
        genesis+: {
          runtime+: {
            parachainInfo+: { parachainId: 2000 },
          },
        },
      },

      extraArgs: [
        '--state-pruning=archive',
        '--blocks-pruning=archive-canonical',
      ],
      nodes: [
        { name: 'ceres', seed: '//Ceres', key: 'ddb2c74ef1c62df3a280a2ae88265ba6e64329f3c61cb9c2c2c0a4a4fa639c70' },
        { name: 'ganymede', seed: '//Ganymede', key: '44716b4a5478177063f04fb118ff5f84652920278405943768ad3ddcae51b750' },
        { name: 'callisto', seed: '//Callisto', key: '36be65a14a1b2b1e040d23b603d4dde21be6c47e2cc02de37d0895a45c505ebc' },
        { name: 'mimas', seed: '//Mimas', key: '81a4db0f0445af74cf1f10613389314f5fd5446c837fb577f4fb3840736bf97b' },
        { name: 'enceladus', seed: '//Enceladus', key: '4133c3390a64f9dbb0eb33f24d93aab317276c0efe88b82078bd854bc85e946a' },
        { name: 'tethys', seed: '//Tethys', key: '049968395176c9fcc4241bf3eff5b3f9ba0f0f74d14229881d24f99c37a3715c' },
        { name: 'dione', seed: '//Dione', key: '3db5ecb6e3bdf08e28402c22ba8b9b9bf308af0f9cc9ceb0eee88d3c15edc5ec' },
        { name: 'rhea', seed: '//Rhea', key: 'de2ea836fd612c1b42e186f61e0b88977044121213f58fd5af8f8b7ca0bbcc51' },
        { name: 'titan', seed: '//Titan', key: 'b10e4e1c0a14385485833973a7eee27e66f91ba187de58c516fb08f8a4005727' },
        { name: 'iapetus', seed: '//Iapetus', key: '7bfc7f5b044eded26da012642edf9d7be44618a4b81435b1e593fb9089d9b348' },
        { name: 'miranda', seed: '//Miranda', key: '2f97ca8fbb2dde2350ae6830aff4e61c295ee468cda3eb843b823edb56e6ac04' },
        { name: 'ariel', seed: '//Ariel', key: 'fa262fa10c0f17ffcee2271076a310ad5009dd789d169b7fde688b58431880d6' },
        { name: 'umbriel', seed: '//Umbriel', key: 'df4da642600c9db44edfbf6431d757b9c36b281d3f0b3c72d23e543151246a0b' },
        { name: 'titania', seed: '//Titania', key: '96fcb81bf0bfcf67fa56ce9c94740a201da801167fcdd89d00880c2a5164b006' },
        { name: 'oberon', seed: '//Oberon', key: 'd8a70acef934957dfde77ff6379c9dd5efdbebf4684de89896ca332eea04339b' },
        { name: 'triton', seed: '//Triton', key: '202ad6f1c95eabd3abbcc26ff708d544100b528ad0a5436cfb8491052d938929' },
        { name: 'pluto', seed: '//Pluto', key: 'ed587e2ed0ee289b58bae83e6d0de2a485c5016539537a4af0f61aaa9dfe7c47' },
        { name: 'charon', seed: '//Charon', key: 'eae57ce518baaf7aad01002c65999c786649f74efed2f7a31029a18941852613' },
        { name: 'eris', seed: '//Eris', key: '815a59d7d50163e7d38aca4035efdff9f49f19c12208e6d7e230c319aed4cd83' },
        { name: 'dysnomia', seed: '//Dysnomia', key: '72aa9adc17704b6773a25508d6d8e2e29015819efa66c9a5213bb99eaefc0e8e' },
      ],
    },
  ],
}
