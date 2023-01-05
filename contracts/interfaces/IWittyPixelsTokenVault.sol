// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITokenVaultWitnet.sol";
import "./IWittyPixelsTokenVaultAuctionDutch.sol";
import "./IWittyPixelsTokenVaultJackpots.sol";

abstract contract IWittyPixelsTokenVault
    is
        ITokenVaultWitnet,
        IWittyPixelsTokenVaultAuctionDutch,
        IWittyPixelsTokenVaultJackpots
{
    constructor(address _randomizer)
        ITokenVaultWitnet(_randomizer)
    {}

    function totalScore() virtual external view returns (uint256);
}