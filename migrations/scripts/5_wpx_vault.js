const addresses = require("../addresses")
const package = require ("../../package")
const utils = require("../../scripts/utils")

const WittyPixelsToken = artifacts.require("WittyPixelsToken")
const WittyPixelsTokenVault = artifacts.require("WittyPixelsTokenVault")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var vault
  if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsTokenVaultPrototype)) {
    await deployer.deploy(
      WittyPixelsTokenVault,
      utils.fromAscii(package.version),
      { from }
    )
    vault = await WittyPixelsTokenVault.deployed()
    addresses[ecosystem][network].WittyPixelsTokenVaultPrototype = vault.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    vault = await WittyPixelsTokenVault.at(addresses[ecosystem][network].WittyPixelsTokenVaultPrototype)
    utils.traceHeader("Skipping 'WittyPixelsTokenVaultPrototype'")
    console.info("  ", "> contract address:", vault.address)
    console.info()
  }

  if (network !== "test") {
    var token = await WittyPixelsToken.at(addresses[ecosystem][network].WittyPixelsTokenProxy)
    var prototype = await token.tokenVaultPrototype.call({ from })
    if (prototype.toLowerCase() !== vault.address.toLowerCase()) {
      const header = `Setting WittyPixelsTokenProxy's prototype...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old vault prototype:", prototype)
      console.info("   > new vault prototype:", vault.address, `(v${await vault.version.call({ from })})`)
      const tx = await token.setTokenVaultFactoryPrototype(vault.address, { from })
      console.info("   => transaction hash :", tx.receipt.transactionHash)
      console.info("   => transaction gas  :", tx.receipt.gasUsed)
    }
  }
}