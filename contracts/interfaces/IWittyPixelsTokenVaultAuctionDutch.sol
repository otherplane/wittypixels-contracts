// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWittyPixelsTokenVaultAuctionDutch {
    
    event SettingsChanged(address indexed from, Settings settings);
    
    struct Settings {
        uint256 deltaPrice;
        uint256 reservePrice;
        uint256 roundBlocks;
        uint256 startingBlock;
        uint256 startingPrice;
    }
    
    function afmijnen() external payable;
    function auctioning() external view returns (bool);
    function price() external view returns (uint256);
    function nextRoundBlock() external view returns (uint256);
    function settings() external view returns (Settings memory);
}