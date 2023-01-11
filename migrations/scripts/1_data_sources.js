const fs = require("fs")

const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network) {
  if (network !== "test") {
    const isDryRun = network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    var witnetAddresses
    if (!isDryRun) {
      try {
        witnetAddresses = require("witnet-solidity-bridge/migrations/witnet.addresses")[ecosystem][network]
        WitnetBytecodes.address = witnetAddresses.WitnetBytecodes
      } catch (e) {
        console.error("Fatal: Witnet Foundation addresses were not provided!", e)
        process.exit(1)
      }
    } else {
      await deployer.deploy(WitnetEncodingLib)
      await deployer.link(WitnetEncodingLib, WitnetBytecodes)
      await deployer.deploy(WitnetBytecodes, true, utils.fromAscii(network), { gas: 6721975 })
    }

    const witnetRegistry = await WitnetBytecodes.deployed()
    const witnetHashes = require("../witnet/hashes")
    
    const witnetSources = require("../witnet/sources.js")
    for (const key in witnetSources) {
      if (!witnetHashes.sources) witnetHashes.sources = {}
      if (
        !witnetHashes.sources[key]
          || witnetHashes.sources[key] === ""
          || witnetHashes.sources[key] === "0x"
          || reducerNotRegistered(witnetRegistry, witnetHashes.sources[key])
      ) {
        const source = witnetSources[key]
        const header = `Verifying Witnet data source '${key}'...`
        console.info("  ", header)
        console.info("  ", "-".repeat(header.length))
        console.info()
        console.info(`   > Request schema:      ${source.requestSchema || "https://"}`)
        console.info(`   > Request method:      ${await source.requestMethod || 1}`)
        console.info(`   > Request authority:   ${source.requestAuthority}`)
        if (source.requestPath)  {
          console.info(`   > Request path:        ${source.requestPath}`)
        }
        if (source.requestQuery) {
          console.info(`   > Request query:       ${source.requestQuery}`)
        }
        if (source.requestBody) {
          console.info(`   > Request body:        ${source.requestBody}`)
        }
        if (source.requestHeaders) {
          console.info(`   > Request headers:     ${source.requestHeaders}`)
        }
        console.info(`   > Request script:      ${source.requestScript || "0x80"}`)
        const tx = await witnetRegistry.verifyDataSource(
          await source.requestMethod || 1,
          0, 0,
          source.requestSchema || "https://",
          source.requestAuthority,
          source.requestPath || "",
          source.requestQuery || "",
          source.requestBody || "",
          source.requestHeaders || [],
          source.requestScript || "0x80"
        )
        console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
        console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
        witnetHashes.sources[key] = tx.logs[1].args.hash
        console.info(`   > data source hash:    ${witnetHashes.sources[key]}`)
        console.info()
        saveHashes(witnetHashes)
      }
    }

    const witnetSLAs = require("../witnet/slas")
    await Promise.all(Object.keys(witnetSLAs).map(async key => {
      if (!witnetHashes.slas) witnetHashes.slas = {}
      if (
        !witnetHashes.slas[key]
          || witnetHashes.slas[key] === ""
          || witnetHashes.slas[key] === "0x"
          || slaNotRegistered(witnetRegistry, witnetHashes.slas[key])
      ) {
        const sla = witnetSLAs[key]
        const header = `Verifying Witnet radon SLA '${key}'...`
        console.info("  ", header)
        console.info("  ", "-".repeat(header.length))
        console.info()
        console.info(`   > Number of witnesses:   ${sla.numWitnesses}`)
        console.info(`   > Consensus quorum:      ${sla.minConsensusPercentage}%`)
        console.info(`   > Commit/Reveal fee:     ${sla.commitRevealFee} nanoWits`)
        console.info(`   > Witnessing reward:     ${sla.witnessReward} nanoWits`)
        console.info(`   > Witnessing collateral: ${sla.collateral} nanoWits`)
        const tx = await witnetRegistry.verifyRadonSLA([
          sla.witnessReward,
          sla.numWitnesses,
          sla.commitRevealFee,
          sla.minConsensusPercentage,
          sla.collateral
        ])
        console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
        console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
        witnetHashes.slas[key] = tx.logs[0].args.hash
        console.info(`   > radon SLA hash:      ${witnetHashes.slas[key]}`)
        console.info()
        saveHashes(witnetHashes)
      }
    }))

    const witnetReducers = require("../witnet/reducers.js")
    await Promise.all(Object.keys(witnetReducers).map(async key => {
      if (!witnetHashes.reducers) witnetHashes.reducers = {}
      if (
        !witnetHashes.reducers[key]
          || witnetHashes.reducers[key] === ""
          || witnetHashes.reducers[key] === "0x"
          || reducerNotRegistered(witnetRegistry, witnetHashes.reducers[key])
      ) {
        const reducer = witnetReducers[key]
        const header = `Verifying Witnet radon reducer '${key}'...`
        console.info("  ", header)
        console.info("  ", "-".repeat(header.length))
        console.info()
        console.info(`   > Reducer opcode:      ${reducer.opcode}`)
        console.info(`   > Reducer filters:     ${reducer.filters || '(no filters)'}`)
        const tx = await witnetRegistry.verifyRadonReducer([
          reducer.opcode,
          reducer.filters,
          reducer.script
        ])
        console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
        console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
        witnetHashes.reducers[key] = tx.logs[0].args.hash
        console.info(`   > radon reducer hash:  ${witnetHashes.reducers[key]}`)
        console.info()
        saveHashes(witnetHashes)
      }
    }))
  }
}

function saveHashes(hashes) {
  fs.writeFileSync(
    "./migrations/witnet/hashes.json",
    JSON.stringify(hashes, null, 4),
    { flag: 'w+'}
  )
}

async function reducerNotRegistered(bytecodes, hash) {
  try {
    await bytecodes.lookupDataSource.call(hash)
    return false
  } catch {
    return true
  }
}

async function slaNotRegistered(bytecodes, hash) {
  try {
    var sla = await bytecodes.lookupRadonSLA.call(hash)
    return sla[0] != 0
  } catch {
    return true
  }
}