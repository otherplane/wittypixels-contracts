// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "witnet-solidity-bridge/contracts/libs/WitnetCBOR.sol";

import "../libs/WittyPixels.sol";

contract WitnetRequestTokenRoots
    is
        WitnetRequestTemplate
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WittyPixels for bytes;

    constructor (
            WitnetRequestBoard _witnet,
            IWitnetBytecodes _registry,
            bytes32[] memory _sources,
            bytes32 _aggregator
        )
        WitnetRequestTemplate(
            _witnet,
            _registry,
            _sources,
            _aggregator,
            WitnetV2.RadonDataTypes.Array
        )
    {}

    function _read(WitnetCBOR.CBOR memory _value)
        internal pure
        override
        returns (bytes memory _result)
    {
        WitnetCBOR.CBOR[] memory _items = _value.readArray();
        if (_items.length >= 3) {
            _result = abi.encode(WittyPixels.TokenRoots({
                data: _items[0].readBytes().toBytes32(),
                names: _items[1].readBytes().toBytes32(),
                scores: _items[2].readBytes().toBytes32()
            }));
        }
    }
}