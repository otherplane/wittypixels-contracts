const fs = require("fs")

const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")
const WitnetLib = artifacts.require("WitnetLib")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoardTrustableDefault")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var witnetAddresses
  if (!isDryRun) {
    try {
      witnetAddresses = require("witnet-solidity-bridge/migrations/witnet.addresses")[ecosystem][network]
      WitnetBytecodes.address = witnetAddresses.WitnetBytecodes
      WitnetRequestBoard.address = witnetAddresses.WitnetRequestBoard
    } catch (e) {
      console.error("Fatal: Witnet Foundation addresses were not provided!", e)
      process.exit(1)
    }
  } else {
    await deployer.deploy(WitnetEncodingLib, { from })
    await deployer.link(WitnetEncodingLib, WitnetBytecodes)
    await deployer.deploy(WitnetBytecodes, true, utils.fromAscii(network), { from, gas: 6721975 })
    await deployer.deploy(WitnetLib, { from })
    await deployer.link(WitnetLib, WitnetRequestBoard)
    await deployer.deploy(WitnetRequestBoard, true, utils.fromAscii(network), 135000, { from, gas: 6721975 })
  }

  const witnetRegistry = await WitnetBytecodes.deployed()
  const witnetHashes = require("../witnet/hashes")
  
  if (!witnetHashes.sources) witnetHashes.sources = {}    
  const witnetSources = require("../witnet/sources.js")
  for (const key in witnetSources) {      
    const source = witnetSources[key]
    const header = `Verifying Witnet data source '${key}'...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
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
    // get actual hash for this data source
    var hash = await witnetRegistry.verifyDataSource.call(
      await source.requestMethod || 1,
      0, 0,
      source.requestSchema || "https://",
      source.requestAuthority,
      source.requestPath || "",
      source.requestQuery || "",
      source.requestBody || "",
      source.requestHeaders || [],
      source.requestScript || "0x80",
      { from }
    )
    // register the data source if actual hash differs from hashes file
    if (hash !== witnetHashes.sources[key]) {
      const tx = await witnetRegistry.verifyDataSource(
        await source.requestMethod || 1,
        0, 0,
        source.requestSchema || "https://",
        source.requestAuthority,
        source.requestPath || "",
        source.requestQuery || "",
        source.requestBody || "",
        source.requestHeaders || [],
        source.requestScript || "0x80",
        { from }
      )
      console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
      console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
      hash = tx.logs[tx.logs.length - 1].args.hash
      console.info(`   < new data source hash:${hash}`)
    } else {
      console.info(`   $ Already verified as: ${hash}`)
    }
    witnetHashes.sources[key] = hash      
    saveHashes(witnetHashes)
  }

  if (!witnetHashes.slas) witnetHashes.slas = {}
  const witnetSLAs = require("../witnet/slas")
  for (const key in witnetSLAs) {    
    const sla = witnetSLAs[key]
    const header = `Verifying Witnet radon SLA '${key}'...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
    console.info(`   > Number of witnesses:   ${sla.numWitnesses}`)
    console.info(`   > Consensus quorum:      ${sla.minConsensusPercentage}%`)
    console.info(`   > Commit/Reveal fee:     ${sla.commitRevealFee} nanoWits`)
    console.info(`   > Witnessing reward:     ${sla.witnessReward} nanoWits`)
    console.info(`   > Witnessing collateral: ${sla.collateral} nanoWits`)
    // get actual hash for this radon SLA
    var hash = await witnetRegistry.verifyRadonSLA.call([
      sla.witnessReward,
        sla.numWitnesses,
        sla.commitRevealFee,
        sla.minConsensusPercentage,
        sla.collateral,
      ], 
      { from }
    )
    // register the SLA if actual hash differs from hashes file
    if (hash !== witnetHashes.slas[key]) {
      const tx = await witnetRegistry.verifyRadonSLA([
          sla.witnessReward,
          sla.numWitnesses,
          sla.commitRevealFee,
          sla.minConsensusPercentage,
          sla.collateral,
        ], 
        { from }
      )
      console.info(`   > transaction hash:      ${tx.receipt.transactionHash}`)
      console.info(`   > gas used:              ${tx.receipt.gasUsed}`)        
      hash = tx.logs[tx.logs.length - 1].args.hash
      console.info(`   < new radon SLA hash:    ${hash}`)
    } else {
      console.info(`   $ Already verified as:   ${hash}`)
    }
    witnetHashes.slas[key] = hash
    saveHashes(witnetHashes)
  }

  if (!witnetHashes.reducers) witnetHashes.reducers = {}
  const witnetReducers = require("../witnet/reducers.js")
  for (const key in witnetReducers) {    
    const reducer = witnetReducers[key]
    const header = `Verifying Witnet radon reducer '${key}'...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
    console.info(`   > Reducer opcode:      ${reducer.opcode}`)
    console.info(`   > Reducer filters:     ${reducer.filters.length > 0 ? reducer.filters : '(no filters)'}`)
    // get actual hash for this radon reducer
    var hash = await witnetRegistry.verifyRadonReducer.call([
      reducer.opcode,
        reducer.filters,
        reducer.script,
      ],
      { from }
    )
    // register the reducer if actual hash differs from hashes file
    if (hash !== witnetHashes.reducers[key]) {
      const tx = await witnetRegistry.verifyRadonReducer([
          reducer.opcode,
          reducer.filters,
          reducer.script,
        ],
        { from }
      )
      console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
      console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
      hash = tx.logs[tx.logs.length - 1].args.hash
      console.info(`   < new reducer hash:    ${hash}`)
    } else {
      console.info(`   $ Already verified as: ${hash}`)
    }
    witnetHashes.reducers[key] = hash
    saveHashes(witnetHashes)
  }
  console.info()
}

function saveHashes(hashes) {
  fs.writeFileSync(
    "./migrations/witnet/hashes.json",
    JSON.stringify(hashes, null, 4),
    { flag: 'w+'}
  )
}