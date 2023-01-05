// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;


import "witnet-solidity-bridge/contracts/libs/WitnetCBOR.sol";
import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";

contract WitnetRequestImageDigest
    is
        WitnetRequestTemplate
{
    using WitnetCBOR for WitnetCBOR.CBOR;

    constructor (
            WitnetRequestBoard _witnet,
            IWitnetBytecodes _registry,
            bytes32[] memory _sources,
            bytes32 _aggregator,
            bytes32 _tally
        )
        WitnetRequestTemplate(
            _witnet,
            _registry,
            _sources,
            _aggregator,
            _tally,
            WitnetV2.RadonDataTypes.String,
            0
        )
    {}

    function _read(WitnetCBOR.CBOR memory _value)
        internal pure
        override
        returns (bytes memory)
    {
        return _value.readBytes();
    }

    // web3.eth.abi.encodeParameter({"InitData": {"args":'string[][]',"tallyHash":'bytes32',"slaHash":'bytes32',"resultMaxSize":'uint16'}}, { args: [["api.wittypixels.art/images/1.png"]], tallyHash: "0x5c6037e17112ad2502ced33a32a65e1df780e7996de2b65aff08f47c4c58a3d0", slaHash: "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64", resultMaxSize: 0 })
}