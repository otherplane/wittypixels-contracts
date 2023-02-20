// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";
import "../libs/WittyPixelsLib.sol";

interface IWittyPixelsTokenAdmin {
    
    event Launched(uint256 tokenId, WittyPixelsLib.ERC721TokenEvent theEvent);
    event Minting(uint256 tokenId, string baseURI, WitnetV2.RadonSLA witnetSLA);

    event NewTokenSponsor(uint256 tokenId, uint256 index, address indexed addr);

    function launch(WittyPixelsLib.ERC721TokenEvent calldata theEvent) external returns (uint256 tokenId);
    
    /// @notice Mint next WittyPixelsTM token: one new token id per ERC721TokenEvent where WittyPixelsTM is played.
    /// @param witnetSLA Witnessing SLA parameters of underlying data requests to be solved by the Witnet oracle.
    function mint(WitnetV2.RadonSLA calldata witnetSLA) external payable;

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata baseURI) external;

    /// @notice Sets token vault contract to be used as prototype in following mints.
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultFactoryPrototype(address prototype) external;    
}