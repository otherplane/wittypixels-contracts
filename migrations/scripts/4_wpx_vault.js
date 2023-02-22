const ethUtils = require('ethereumjs-util');

const addresses = require("../addresses")
const singletons = require("../singletons")
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
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
    const factory = await Create2Factory.deployed()
    if (
      factory && !utils.isNullAddress(factory.address)
        && singletons?.WittyPixelsTokenVaultPrototype
    ) {
      const bytecode = WittyPixelsTokenVault.toJSON().bytecode
      const salt = singletons.WittyPixelsTokenVaultPrototype?.salt
        ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WittyPixelsTokenVaultPrototype.salt
            ), 32
          ).toString("hex")
        : "0x0"
      ;
      const prototypeAddr = await factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(prototypeAddr)).length <= 3) {
        // deploy new instance only if not found current network:
        utils.traceHeader(`Singleton incepton of 'WittyPixelsTokenVaultPrototype':`)
        const balance = await web3.eth.getBalance(from)
        const gas = singletons?.WittyPixelsTokenVaultPrototype?.gas || 5 * 10 ** 6
        const tx = await factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader(`Singleton 'WittyPixelsTokenVaultPrototype':`)
      }
      WittyPixelsTokenVault.address = prototypeAddr
      console.info("  ", "> prototype address:       ", prototypeAddr)
      console.info("  ", "> prototype codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(prototypeAddr)))
      console.info("  ", "> prototype inception salt:", salt)
    } else {
      // Deploy no singleton prototype ...
      await deployer.deploy(
        WittyPixelsTokenVault,
        { from }
      )
    }
    vault = await WittyPixelsTokenVault.deployed()
    // update addresses file 
    addresses[ecosystem][network].WittyPixelsTokenVaultPrototype = vault.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    vault = await WittyPixelsTokenVault.at(addresses[ecosystem][network].WittyPixelsTokenVaultPrototype)
    utils.traceHeader("Skipping 'WittyPixelsTokenVaultPrototype'")
    console.info("  ", "> prototype address:", vault.address)
    console.info()
  }

  if (network !== "test") {
    var token = await WittyPixelsToken.at(WittyPixelsToken.address)
    var prototype = await token.getTokenVaultFactoryPrototype.call({ from })
    if (prototype.toLowerCase() !== vault.address.toLowerCase()) {
      const header = `Setting WittyPixelsTokenProxy's prototype...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old vault prototype:", prototype)
      console.info("   > new vault prototype:", vault.address)
      const tx = await token.setTokenVaultFactoryPrototype(vault.address, { from })
      console.info("   > transaction hash   :", tx.receipt.transactionHash)
      console.info("   > transaction gas    :", tx.receipt.gasUsed)
    }
  }
}