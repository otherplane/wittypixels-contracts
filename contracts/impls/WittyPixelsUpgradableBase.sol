// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase

pragma solidity >=0.8.0 <0.9.0;

import "witnet-solidity-bridge/contracts/patterns/Ownable2Step.sol";
import "witnet-solidity-bridge/contracts/patterns/ReentrancyGuard.sol";
import "witnet-solidity-bridge/contracts/patterns/Upgradable.sol";

/// @title Witnet Request Board base contract, with an Upgradable (and Destructible) touch.
/// @author The Witnet Foundation.
abstract contract WittyPixelsUpgradableBase
    is
        Ownable2Step,
        Upgradable, 
        ReentrancyGuard
{
    bytes32 internal immutable _UPGRADABLE_VERSION_TAG;

    error AlreadyInitialized(address implementation);
    error NotCompliant(bytes4 interfaceId);
    error NotUpgradable(address self);
    error OnlyOwner(address owner);

    constructor(
            bool _upgradable,
            bytes32 _versionTag,
            string memory _proxiableUUID
        )
        Upgradable(_upgradable)
    {
        _UPGRADABLE_VERSION_TAG = _versionTag;
        proxiableUUID = keccak256(bytes(_proxiableUUID));
    }

    receive() external payable virtual;
    
    /// @dev Reverts if proxy delegatecalls to unexistent method.
    fallback() external payable {
        revert("WittyPixelsUpgradableBase: not implemented");
    }


    // ================================================================================================================
    // --- Overrides 'Proxiable' --------------------------------------------------------------------------------------

    /// @dev Gets immutable "heritage blood line" (ie. genotype) as a Proxiable, and eventually Upgradable, contract.
    ///      If implemented as an Upgradable touch, upgrading this contract to another one with a different 
    ///      `proxiableUUID()` value should fail.
    bytes32 public immutable override proxiableUUID;


    // ================================================================================================================
    // --- Overrides 'Upgradable' --------------------------------------------------------------------------------------

    /// Retrieves human-readable version tag of current implementation.
    function version() public view override returns (string memory) {
        return _toString(_UPGRADABLE_VERSION_TAG);
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    /// Converts bytes32 into string.
    function _toString(bytes32 _bytes32)
        internal pure
        returns (string memory)
    {
        bytes memory _bytes = new bytes(_toStringLength(_bytes32));
        for (uint _i = 0; _i < _bytes.length;) {
            _bytes[_i] = _bytes32[_i];
            unchecked {
                _i ++;
            }
        }
        return string(_bytes);
    }

    // Calculate length of string-equivalent to given bytes32.
    function _toStringLength(bytes32 _bytes32)
        internal pure
        returns (uint _length)
    {
        for (; _length < 32; ) {
            if (_bytes32[_length] == 0) {
                break;
            }
            unchecked {
                _length ++;
            }
        }
    }

}