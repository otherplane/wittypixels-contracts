// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";
import "../libs/WittyPixelsLib.sol";

interface IWittyPixelsTokenAdmin {

    error PremintPendingResponse (uint tokenId, string uri);
    error PremintFailedResponse  (uint tokenId, string uri, string reason);
    error PremintValidationFailed(uint tokenId, string uri, string reason);
    
    event Launched(uint256 tokenId, WittyPixelsLib.ERC721TokenEvent theEvent);
    event Minting(uint256 tokenId, string imageURI, bytes32 slaHash);

    event NewTokenSponsor(uint256 tokenId, uint256 index, address indexed addr);

    function launch(WittyPixelsLib.ERC721TokenEvent calldata theEvent) external returns (uint256 tokenId);
    
    /// @notice Mint new WittyPixelsLib token: one new token id per ERC721TokenEvent where WittyPixelsTM is played.
    function mint(uint256 tokenId, bytes32 witnetSlaHash) external payable;

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata baseURI) external;

    /// @notice Update sponsors access-list by adding new players. 
    /// @dev If already included in the list, texts could still be updated.
    function setTokenSponsors(uint256 tokenId, address[] calldata addresses, string[] calldata texts) external;

    /// @notice Sets token vault contract to be used as prototype in following mints.
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address prototype) external;    
}