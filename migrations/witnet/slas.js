const Witnet = require("witnet-requests")
module.exports = {
    "high-1": {
        witnessReward: 10 ** 9,
        numWitnesses: 1,
        minConsensusPercentage: 75,
        commitRevealFee: 10 ** 6,
        collateral: 5 * 10 ** 9
    },
    "high-16": {
        witnessReward: 10 ** 9,
        numWitnesses: 16,
        minConsensusPercentage: 75,
        commitRevealFee: 10 ** 6,
        collateral: 5 * 10 ** 9
    },
}