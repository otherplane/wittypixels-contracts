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

    const settings = require("../../settings").core.events[index].fractionalize
    if (!settings) {
        console.error(`No fractionalizing parameters found for token #${index + 1} !`)
        process.exit(2)
    }

    utils.traceHeader(`Fractionalizing token #${index + 1} on '${name}' collection`)
    console.info("  ", "> from address:  ", from)
    console.info("  ", "> token address: ", token.address)    
    console.info("  ", "> current status:", await token.getTokenStatusString.call(index + 1))
    console.info("  ", "> create2 salt:  ", settings.salt)
    console.info("  ", "> auction settings:")
    console.info("  ", `  - deltaPrice:        ${web3.utils.fromWei(settings.auctionSettings.deltaPrice)} ETH`)
    console.info("  ", `  - deltaSeconds:      ${settings.auctionSettings.deltaSeconds} "`)
    console.info("  ", `  - reservePrice:      ${web3.utils.fromWei(settings.auctionSettings.reservePrice)} ETH`)
    console.info("  ", `  - startingPrice:     ${web3.utils.fromWei(settings.auctionSettings.startingPrice)} ETH`)
    console.info("  ", "  - startingTs:       ", new Date(settings.auctiongSettings.startingTs * 1000).toString())
    
    var balance = await web3.eth.getBalance(from)
    var tx
    try {
        tx = await token.fractionalize(
            settings.salt, 
            web3.eth.abi.encodeParameter(
                "uint256[5]", [
                    settings.auctionSettings.deltaPrice,
                    settings.auctionSettings.deltaSeconds,
                    settings.auctionSettings.reservePrice,
                    settings.auctionSettings.startingPrice,
                    settings.auctionSettings.startingTs,
                ]
            ), { from }
        )
    } catch (e) {
        console.error(`Couldn't fractionalize: ${e}`)
        process.exit(3)
    }
    console.info("  ", "> Done:")
    console.info("  ", "  - transaction hash:", tx.tx)
    console.info("  ", "  - transaction gas: ", tx.receipt.gasUsed)
    console.info("  ", "  - eff. gas price:  ", tx.receipt.effectiveGasPrice / 10 ** 9, "gwei")
    console.info("  ", "  - block number:    ", tx.receipt.blockNumber)
    console.info("  ", "  - total cost:      ", web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString()), "ETH")
    console.info()
}