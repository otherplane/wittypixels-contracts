// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWittyPixelsTokenVaultAuctionDutch {
    
    event SettingsChanged(address indexed from, Settings settings);
    
    struct Settings {
        uint256 deltaPrice;
        uint256 deltaSeconds;
        uint256 reservePrice;
        uint256 startingPrice;
        uint256 startingTs;
    }
    
    function acquire() external payable;
    function auctioning() external view returns (bool);
    function price() external view returns (uint256);
    function nextPriceTimestamp() external view returns (uint256);
    function settings() external view returns (Settings memory);
    function setDutchAuction(bytes calldata) external;
}