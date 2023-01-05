const { merge } = require("lodash")
module.exports = {
  core: {
    collection: {
      baseURI: "https://api.wittypixels.com/",
      name: "WittyPixels.art",
      symbol: "ART",
      upgradable: true,
    },
    vaults: [
      {},
    ],
  },  
  compilers: {
    default: {
      solc: {
        version: "0.8.17",
        // viaIR: true,
        settings: {
          optimizer: {            
            enabled: true,
            runs: 200, 
            details: {
              yul: true
            }
          },
          
        },
        outputSelection: {
          "*": {
            "*": ["evm.bytecode"],
          },
        },
      },
    },
  },
  networks: merge(
    require("witnet-solidity-bridge/migrations/witnet.settings").networks, {
      default: {
        "ethereum.mainnet": {
          skipDryRun: true,
          confirmations: 2,
        },
      },
      polygon: {
        "polygon.goerli": {
          gasPrice: 50 * 10 ** 9,
          confirmations: 2,
        },
      },
    }
  )
}