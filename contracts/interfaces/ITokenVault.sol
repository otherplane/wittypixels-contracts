// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IERC165.sol";
import "./IERC1633.sol";

abstract contract ITokenVault
    is 
        IERC20,
        IERC165,
        IERC1633
{
    /// @notice Address of the previous owner, the one that decided to fractionalized the NFT.
    function curator() virtual external view returns (address);

    // /// @notice Redeems whole ownership to Fractionalized NFT, if paying required price.
    // function buyOut() virtual external payable;

    /// @notice Returns whether this NFT vault has already been sold out. 
    function soldOut() virtual external view returns (bool);

    /// @notice Withdraw paid value in proportion to number of shares.
    /// @dev Fails if not yet sold out. 
    function withdraw() virtual external returns (uint256);

    /// @notice Tells withdrawable amount in weis from given address.
    /// @dev Returns 0 in all cases while not yet sold out. 
    function withdrawableFrom(address from) virtual external view returns (uint256);
}