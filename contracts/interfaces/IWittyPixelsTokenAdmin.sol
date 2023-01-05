// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";
import "../libs/WittyPixels.sol";

interface IWittyPixelsTokenAdmin {

    error PremintPendingResponse (uint tokenId, string uri);
    error PremintFailedResponse  (uint tokenId, string uri, string reason);
    error PremintValidationFailed(uint tokenId, string uri, string reason);
    
    event Minting(uint256 tokenId, string baseURI, string imageURI, bytes32 slaHash);

    event NewTokenSponsor(uint256 tokenId, uint256 index, address indexed addr);

    function premint(
            uint256 tokenId,
            bytes32 slaHash,
            string calldata imageURI
        ) external payable;

    /// @notice Mint new WittyPixels token: one new token id per ERC721TokenEvent where WittyPixelsTM is played.
    function mint(
            uint256 tokenId,
            WittyPixels.ERC721TokenEvent memory theEvent,
            WittyPixels.ERC721TokenCanvas memory theCanvas,
            WittyPixels.ERC721TokenStats memory theStats
        ) external;

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata baseURI) external;

    /// @notice Update sponsors access-list by adding new members. 
    /// @dev If already included in the list, texts could still be updated.
    function setTokenSponsors(uint256 tokenId, address[] calldata addresses, string[] calldata texts) external;

    /// @notice Sets token vault contract to be used as prototype in following mints.
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address prototype) external;    
}