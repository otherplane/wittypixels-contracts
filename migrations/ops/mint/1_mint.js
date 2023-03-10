const addresses = require("../../addresses")
const utils = require("../../../scripts/utils")
const WittyPixelsToken = artifacts.require("WittyPixelsToken")

module.exports = async function (_deployer, network, [,from]) {

    if (network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop") {
        console.error("Not in dry-run chains !")
        process.exit(1)
    }
    var ecosystem
    [ ecosystem, network ] = utils.getRealmNetworkFromString(network.split("-")[0])
    
    WittyPixelsToken.address = addresses[ecosystem][network].WittyPixelsToken   
    var token = await WittyPixelsToken.deployed()
    var name = await token.name.call({ from })
    var totalSupply = await token.totalSupply.call({ from })
    var index = parseInt(totalSupply) 

    const settings = require("../../settings").core.events[index].mint
    if (!settings) {
        console.error(`No minting parameters found for token #${index + 1} !`)
        process.exit(2)
    }

    utils.traceHeader(`Minting token #${index + 1} on '${name}' collection`)
    console.info("  ", "> from address:  ", from)
    console.info("  ", "> token address: ", token.address)    
    console.info("  ", "> current status:", await token.getTokenStatusString.call(index + 1, { from }))
    console.info("  ", "> Witnet SLA:")
    console.info("  ", `  - numWitnesses:      ${settings.witnetSLA.numWitnesses}`)
    console.info("  ", `  - minConsensusPct:   ${settings.witnetSLA.minConsensusPercentage} %`)
    console.info("  ", `  - minerCommitFee:    ${settings.witnetSLA.minerCommitFee} nanoWits`)
    console.info("  ", `  - witnessReward:     ${settings.witnetSLA.witnessReward} nanoWits`)
    console.info("  ", `  - witnessCollateral: ${settings.witnetSLA.witnessCollateral} nanoWits`)
    
    var balance = await web3.eth.getBalance(from)
    var tx
    try {
        tx = await token.mint([
                settings.witnetSLA.numWitnesses,
                settings.witnetSLA.minConsensusPercentage,
                settings.witnetSLA.witnessReward,
                settings.witnetSLA.witnessCollateral,
                settings.witnetSLA.minerCommitFee
            ], { 
                from,
                value: settings.witnetEvmFee, 
            }
        )
    } catch (e) {
        console.error(`Couldn't start minting: ${e}`)
        process.exit(3)
    }
    console.info()
    console.info("  ", "=> Done:")
    console.info("  ", "  - transaction hash:", tx.tx)
    console.info("  ", "  - transaction gas: ", tx.receipt.gasUsed)
    console.info("  ", "  - eff. gas price:  ", tx.receipt.effectiveGasPrice / 10 ** 9, "gwei")
    console.info("  ", "  - block number:    ", tx.receipt.blockNumber)
    console.info("  ", "  - total cost:      ", web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString()), "ETH")
    console.info("")
}