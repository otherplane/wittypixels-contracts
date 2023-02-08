const { merge } = require("lodash")
module.exports = {
  core: {
    collection: {
      baseURI: "https://api.wittypixels.art/",
      name: "WittyPixels.art",
      symbol: "WPX",
      upgradable: true,
    },
    events: [
      {
        name: "ETHDenver 2023",
        venue: "National Western $SPORK Castle",
        startTs: 1677193200 + 7 * 3600,          // Thu, 24 February 2023 0:00 GMT-7
        endTs:   1677866400 + 7 * 3600,          // Fri, 3 March 2023 18:00 GMT-7
        auction: {
          deltaPrice:       "50000000000000000", //  0.05 ETH
          deltaSeconds:                    3600, //     1 hour
          reservePrice:   "1000000000000000000", //  1.00 ETH
          startingPrice: "32000000000000000000", // 32.00 ETH
          startingTs:     1677974400 + 7 * 3600, // Sun, 5 March 2023 0:00 GMT-7
        }
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
          // gasPrice: 50 * 10 ** 9,
          confirmations: 2,
          // gas: 1000000,
        },
      },
    }
  )
}