const ethUtils = require('ethereumjs-util');

const addresses = require("../addresses")
const package = require ("../../package")
const settings = require("../settings")
const singletons = require("../singletons")
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")

const WitnetProxy = artifacts.require("WitnetProxy")
const WittyPixelsLib = artifacts.require("WittyPixelsLib")
const WittyPixelsToken = artifacts.require("WittyPixelsToken")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var lib
  if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsLib)) {
    await deployer.deploy(WittyPixelsLib, { from })
    lib = await WittyPixelsLib.deployed()
    addresses[ecosystem][network].WittyPixelsLib = lib.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    lib = await WittyPixelsLib.at(addresses[ecosystem][network]?.WittyPixelsLib)
    WittyPixelsLib.address = lib.address
    utils.traceHeader("Skipping 'WittyPixelsLib'")
    console.info("  ", "> library address:", lib.address)
    console.info()
  }

  var token
  if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsTokenImplementation)) {
    var wrbAddress
    if (isDryRun) {
      const wrb = artifacts.require("WitnetRequestBoardTrustableDefault")
      wrbAddress = wrb.address
    } else {
      try {
        var witnetAddresses = require("witnet-solidity-bridge/migrations/witnet.addresses")
        wrbAddress = witnetAddresses[ecosystem][network].WitnetRequestBoard
      } catch {
        console.error("Fatal: Witnet Foundation addresses were not provided!")
        process.exit(1)
      }
    }
    await deployer.link(WittyPixelsLib, WittyPixelsToken);
    await deployer.deploy(
      WittyPixelsToken,
      wrbAddress,
      addresses[ecosystem][network].WitnetRequestTemplateImageDigest,
      addresses[ecosystem][network].WitnetRequestTemplateTokenStats,
      settings.core.collection.upgradable,
      utils.fromAscii(package.version),
      { from }
    )
    token = await WittyPixelsToken.deployed()
    addresses[ecosystem][network].WittyPixelsTokenImplementation = token.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    token = await WittyPixelsToken.at(addresses[ecosystem][network].WittyPixelsTokenImplementation)
    utils.traceHeader("Skipping 'WittyPixelsToken'")
    console.info("  ", "> contract address:", token.address)
    console.info()
  }

  if (network !== "test") {
    const factory = await Create2Factory.deployed()    
    var proxy
    if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsToken)) {
      if(
        factory && !utils.isNullAddress(factory.address)
          && singletons?.WittyPixelsToken
      ) {
        // Deploy the proxy via a singleton factory and a salt...
        const bytecode = WitnetProxy.toJSON().bytecode
        const salt = singletons.WittyPixelsToken?.salt 
          ? "0x" + ethUtils.setLengthLeft(
              ethUtils.toBuffer(
                singletons.WittyPixelsToken.salt
              ), 32
            ).toString("hex")
          : "0x0"
        ;
        const proxyAddr = await factory.determineAddr.call(bytecode, salt, { from })
        if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
          // deploy instance only if not found in current network:
          utils.traceHeader(`Singleton inception of 'WittyPixelsToken':`)
          const balance = await web3.eth.getBalance(from)
          const gas = singletons.WittyPixelsToken.gas || 10 ** 6
          const tx = await factory.deploy(bytecode, salt, { from, gas })
          utils.traceTx(
            tx.receipt,
            web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
          )
        } else {
          utils.traceHeader(`Singleton 'WittyPixelsToken':`)
        }
        proxy = await WitnetProxy.at(proxyAddr)
        console.info("  ", "> proxy address:       ", proxyAddr)
        console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))        
        console.info("  ", "> proxy inception salt:", salt)
      } else {
        // Deploy no singleton proxy ...
        await deployer.deploy(WitnetProxy, { from })
        proxy = await WitnetProxy.deployed()
      }
      // update addresses file      
      addresses[ecosystem][network].WittyPixelsToken = proxy.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetProxy.at(addresses[ecosystem][network].WittyPixelsToken)
      utils.traceHeader("Skipping 'WittyPixelsToken'")
      console.info("  ", "> proxy address:", proxy.address)
      console.info()
    }

    var implementation = await proxy.implementation.call({ from })
    if (implementation.toLowerCase() !== token.address.toLowerCase()) {
      const header = `Upgrading 'WittyPixelsToken' at ${proxy.address}...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old implementation:", implementation)
      console.info("   > new implementation:", token.address, `(v${await token.version.call({ from })})`)
      if (implementation === "0x0000000000000000000000000000000000000000" ) {
        console.info("   > new token base uri:", settings.core.collection.baseURI)
      }      
      try {
        const tx = await proxy.upgradeTo(
          token.address,        
          web3.eth.abi.encodeParameter(
            "string[3]", [
              settings.core.collection.baseURI,
              settings.core.collection.name,
              settings.core.collection.symbol
            ]
          ),
          { from }
        )
        console.info("   => transaction hash :", tx.receipt.transactionHash)
        console.info("   => transaction gas  :", tx.receipt.gasUsed)
      } catch (ex) {
        console.error("   !! Cannot upgrade the token proxy:")
        console.error(ex)
      }
    }
  }
}