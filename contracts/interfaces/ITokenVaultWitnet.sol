// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "witnet-solidity-bridge/contracts/interfaces/IWitnetRandomness.sol";
import "./ITokenVault.sol";

abstract contract ITokenVaultWitnet
    is
        ITokenVault
{
    IWitnetRandomness immutable public randomizer;

    constructor(address _randomizer) {
        assert(_randomizer != address(0));
        randomizer = IWitnetRandomness(_randomizer);
    }

    function cloneAndInitialize(bytes calldata) virtual external returns (ITokenVaultWitnet);
    function cloneDeterministicAndInitialize(bytes32, bytes calldata) virtual external returns (ITokenVaultWitnet);

    function getRandomizeBlock() virtual external view returns (uint256);
    function getRandomizeFee(uint256 gasPrice) virtual external view returns (uint256) {
        return randomizer.estimateRandomizeFee(gasPrice);
    }
    function isRandomized() virtual external view returns (bool);
    function isRandomizing() virtual external view returns (bool);
    
}