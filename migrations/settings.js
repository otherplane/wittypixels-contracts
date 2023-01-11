const { merge } = require("lodash")
module.exports = {
  core: {
    collection: {
      baseURI: "https://api.wittypixels.com/",
      name: "WittyPixels.art",
      symbol: "WPX",
      upgradable: true,
    },
    vaults: [
      {
        type: "",
        value: ""
      },
    ],
  },  
  compilers: {
    default: {
      solc: {
        version: "0.8.17",
        settings: {
          optimizer: {            
            enabled: true,
            runs: 200, 
            
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