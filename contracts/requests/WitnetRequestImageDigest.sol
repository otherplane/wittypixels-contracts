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
            WitnetV2.RadonDataTypes.Integer,
            0
        )
    {}

    function _parseWitnetResult(WitnetCBOR.CBOR memory _value)
        internal pure
        override
        returns (bytes memory)
    {
        return abi.encode(_value.readUint());
    }

    // web3.eth.abi.encodeParameter({"InitData": {"slaHash":'bytes32',"args":'string[][]'}}, { args: [["api.wittypixels.art/image/1.svg"]], slaHash: "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64" })
}