const { merge } = require("lodash")
module.exports = {
  core: {
    collection: {
      baseURI: "https://api.wittypixels.art",
      name: "WittyPixels.art",
      symbol: "WPX",
      upgradable: true,
    },
    events: [
      {
        launch: {
          metadata: {
            name: "ETHDenver 2023",
            venue: "National Western $SPORK Castle",
            whereabouts: "Colorado, USA",
            startTs: 1677222000, // Thu, 24 February 2023 0:00 GMT-7
            endTs:   1677978000, // Sat, 4 March 2023 18:00 GMT-7
          },
          charity: {
            description: "Up to 50% of the $ETH from the first auction sale is to be donated to the [TheGivingBlock's Ukraine Emergency Response Fund](https://thegivingblock.com/campaigns/ukraine-emergency-response-fund/). The rest will be distributed to players proportionally to the $WPX fractions they hold on the [WittyPixelsTM official dapp](https://wittypixels.art). ",
            percentage: 50,
            wallet: "0x07A286BE56d1A769cabf4f47882C9ea1383A5544",
          },
        },
        mint: {
          witnetEvmFee: 10 ** 16, // ETH wei
          witnetSLA: {
            numWitnesses: 17,
            minConsensusPercentage: 66,  // %
            minerCommitFee: "100000000", // 0.1 WIT
            witnessReward: "1000000000", // 1.0 WIT
            witnessCollateral: "15000000000", // 15.0 WIT
          },
        },
        fractionalize: {
          auctionSettings: {
            deltaPrice:       "150000000000000000", //   0.15 ETH
            deltaSeconds:                     3600, //      1 hour
            reservePrice:    "1000000000000000000", //   1.00 ETH
            startingPrice: "100000000000000000000", // 100.00 ETH
            startingTs:                 1678003200, // Sun, 5 March 2023 01:00 GMT-7
          },
          salt: 17538291,
        },
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