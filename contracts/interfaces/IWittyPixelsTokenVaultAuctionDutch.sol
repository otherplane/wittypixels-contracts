// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IWittyPixelsTokenVaultAuction.sol";

abstract contract IWittyPixelsTokenVaultAuctionDutch
    is
        IWittyPixelsTokenVaultAuction
{  
    struct Settings {
        uint256 deltaPrice;
        uint256 deltaSeconds;
        uint256 reservePrice;
        uint256 startingPrice;
        uint256 startingTs;
    }

    function acquire() virtual external payable;
    function getNextPriceTimestamp() virtual external view returns (uint256);
}