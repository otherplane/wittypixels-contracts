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
    var name = await token.name.call()
    var totalSupply = await token.totalSupply.call(0)
    var index = parseInt(totalSupply) 

    const settings = require("../../settings").core.events[index].launch
    if (!settings) {
        console.error(`No event settings found for next token #${index + 1} !`)
        process.exit(2)
    }

    utils.traceHeader(`Launching next event on '${name}' collection`)
    console.info("  ", "> from address:  ", from)
    console.info("  ", "> token address: ", token.address)    
    console.info("  ", "> next token id: ", index + 1)
    console.info("  ", "> current status:", await token.getTokenStatusString.call(index + 1))
    console.info("  ", "> event data:")
    console.info("  ", `  - name:    '${settings.metadata.name}'`)
    console.info("  ", `  - venue:   '${settings.metadata.venue}'`)
    console.info("  ", `  - location:'${settings.metadata.whereabouts}'`)
    console.info("  ", "  - starts: ", new Date(settings.metadata.startTs * 1000).toString())
    console.info("  ", "  - ends:   ", new Date(settings.metadata.endTs * 1000).toString())
    console.info("  ", "> charity settings:")
    console.info("  ", `  - EVM address:  ${settings.charity.wallet || "0x0000000000000000000000000000000000000000"}`)
    console.info("  ", `  - percentage:   ${settings.charity.percentage || 50}%`)
    console.info("  ", `  - description: "${settings.charity.description || ""}"`)
    
    var balance = await web3.eth.getBalance(from)
    var tx
    try {
        tx = await token.launch(
            [
                settings.metadata.name,
                settings.metadata.venue,
                settings.metadata.whereabouts,
                settings.metadata.startTs,
                settings.metadata.endTs,
            ], [
                settings.charity.description || "",
                settings.charity.percentage || 50,
                settings.charity.wallet || "0x0000000000000000000000000000000000000000",
            ], { from }
        )
    } catch (e) {
        console.error(`Couldn't set next event metadata: ${e}`)
        process.exit(3)
    }
    console.info()
    console.info("=>", "Done:")
    console.info("  ", "  - transaction hash:", tx.tx)
    console.info("  ", "  - transaction gas: ", tx.receipt.gasUsed)
    console.info("  ", "  - eff. gas price:  ", tx.receipt.effectiveGasPrice / 10 ** 9, "gwei")
    console.info("  ", "  - block number:    ", tx.receipt.blockNumber)
    console.info("  ", "  - total cost:      ", web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString()), "ETH")
    console.info()
}