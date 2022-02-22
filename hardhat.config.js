require('hardhat-deploy');
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");

const projectId = "d0fb6991f2531e92d0b3bf75";                  
const privateKey = "441f9868114e069248d1e6d22b3db155629b964584e36b0a8469a545ffa47c93";
const privateKey2 = "1ba6c7cc75d518f067512b9d8973481e1075b59b5ee218e81ca96c03e4030c22";
const privateKey3 = "43fc6f8e12b711efbc1355b630746179275862afc3ae67c365d2a7e663b1e160";
const apiKeyForEtherscan = "PJ2V5H4XH4P3PYXJE5JUM6VQRPRHQ56HDV";
const optimizerEnabled = !process.env.OPTIMIZER_DISABLED;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  abiExporter: {
      path: './abis',
      clear: true,
      flat: true,
  },
  etherscan: {
      apiKey: apiKeyForEtherscan,
  },
  gasReporter: {
      currency: 'USD',
      gasPrice: 100,
      enabled: process.env.REPORT_GAS ? true : false,
  },
  mocha: {
      timeout: 30000,
  },
  namedAccounts: {
    anotherUser: {
        default: 0,
        97: '0x9D3f7f55DBEb35E734e7405E8CECaDDB8D7e10b0'
    },
    smartComp: {
        1: '0xb2dc5571f477b1c5b36509a71013bfedd9cc492f',
        97: '0xb2dc5571f477b1c5b36509a71013bfedd9cc492f',
        1337: '0xfA249599b353d964768817A75CB4E59d97758B9D'
    },
    smartBridge: {
        default: 0,
        1: '0xDa63D70332139E6A8eCA7513f4b6E2E0Dc93b693',
        97: '0x729FBE5665dAe652aED9384150d4aF94e45fC2F8',
        1337: '0x729FBE5665dAe652aED9384150d4aF94e45fC2F8'
    },
    goldenTreePool: {
        default: 0,
        1: '0x029Aa20Dcc15c022b1b61D420aaCf7f179A9C73f',
        97: '0xd2146c8D93fD7Edd45C07634af7038E825880a64',
        1337: '0xDAC575ddcdD2Ff269EE5C30420C96028Ba7cB304'
    },
    smartAchievement: {
        default: 0,
        1: '0xdd0134236ab968f39c1ccfc5d3d0de577f73b6d7',
        97: '0xabcd4a0093232d729210c17b35b6aa8f66cab925',
        1337: '0x828987A77f7145494bD86780349B204F32DB494A'
    },
    smartArmy: {
      1: '0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5',
      97: '0x357D51124f59836DeD84c8a1730D72B749d8BC23',
      1337: '0x86E07ab6b97ADcd7897D960B0c61DFE5CEaD2E76'
    },
    smartFarm: {
      1: '0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5',
      97: '0x357D51124f59836DeD84c8a1730D72B749d8BC23',
      1337: '0xb654476d77d59259fF1e7fF38B8c4d408639b844'
    },
    smartLadder: {
      1: '0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5',
      97: '0x357D51124f59836DeD84c8a1730D72B749d8BC23',
      1337: '0xB5D0D6855EE08eb07eC4Ca51061c93D644367a1e'
    },
    usdt: {
        1: '0xBcca60bB61934080951369a648Fb03DF4F96263C',
        97: '0xA11c8D9DC9b66E209Ef60F0C8D969D3CD988782c',
        1337: '0xA11c8D9DC9b66E209Ef60F0C8D969D3CD988782c'
    },
    busd: {
        1: '0xBcca60bB61934080951369a648Fb03DF4F96263C',
        97: '0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47',
        1337: '0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47'
    },
  },
  defaultNetwork: "hardhat",
  networks: {    
      hardhat: {
        // chainId: 4 //ethereum
        chainId: 1337, //ethereum
        // chainId: 97, //ethereum
      },
      localhost: {
        url: "http://127.0.0.1:8545"
      },
      polygonmainnet: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/polygon/mainnet`,
        accounts: [privateKey, privateKey2, privateKey3]
      },
      mumbai: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/polygon/mumbai`,
        accounts: [privateKey, privateKey2, privateKey3]
      },
      ethermainnet: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/eth/mainnet`,
        accounts: [privateKey, privateKey2, privateKey3]
      },
      kovan: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/eth/kovan`,
        accounts: [privateKey, privateKey2, privateKey3]
      },
      rinkeby: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/eth/rinkeby`,
        accounts: [privateKey, privateKey2, privateKey3]
      } ,
      bscmainnet: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/bsc/mainnet`,
        accounts: [privateKey, privateKey2, privateKey3]
      },
      bsctestnet: {
        url: `https://speedy-nodes-nyc.moralis.io/${projectId}/bsc/testnet`,
        accounts: [privateKey, privateKey2, privateKey3]
      }
  },
  solidity: {
      compilers: [
          {
              version: '0.8.4',
              settings: {
                  optimizer: {
                      enabled: optimizerEnabled,
                      runs: 2000,
                  },
                  evmVersion: 'berlin',
              }
          },
          {
            version: '0.6.12',
            settings: {
                optimizer: {
                    enabled: optimizerEnabled,
                    runs: 2000,
                },
                evmVersion: 'berlin',
            }
        },
        {
          version: '0.5.16',
          settings: {
              optimizer: {
                  enabled: optimizerEnabled,
                  runs: 2000,
              },
              evmVersion: 'berlin',
          }
      }
    ],
  },
}

