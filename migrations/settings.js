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
            startTs: 1677247200 + 7 * 3600, // Fri, 24 February 2023, 15:00 GMT+01
            endTs:   1677952800 + 7 * 3600, // Sat, 3 March 2023, 18:00 GMT-07
          },
          charity: {
            description: "Up to 50% of the $ETH from the first auction sale is to be donated to the [TheGivingBlock's Ukraine Emergency Response Fund](https://thegivingblock.com/campaigns/ukraine-emergency-response-fund/). The rest will be distributed to players proportionally to the $WPX fractions they hold on the [WittyPixelsTM official dapp](https://wittypixels.art). ",
            percentage: 50,
            wallet: "",
          },
        },
        mint: {
          witnetSLA: {
            numWitnesses: 16,
            minConsensusPercentage: 75,  // %
            minerCommitFee: "100000000", // 0.1 WIT
            witnessReward: "1000000000", // 1.0 WIT
            witnessCollateral: "15000000000", // 15.0 WIT
          },
        },
        fractionalize: {
          auctionSettings: {
            deltaPrice:       "150000000000000000", //  0.05 ETH
            deltaSeconds:                     3600, //     1 hour
            reservePrice:    "1000000000000000000", //  1.00 ETH
            startingPrice: "100000000000000000000", // 32.00 ETH
            startingTs:      1677974400 + 7 * 3600, // Sun, 5 March 2023 0:00 GMT-7
          },
          salt: "0x0000000000000000000000000000000000000000000000000000000077DEF75A",
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
          confirmations: 2,
        },
      },
    }
  )
}