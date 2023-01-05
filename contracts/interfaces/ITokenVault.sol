// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./IERC165.sol";
import "./IERC1633.sol";

abstract contract ITokenVault
    is 
        IERC20Upgradeable,
        IERC165,
        IERC1633
{
    event SoldOut(address buyer, uint256 value);
    event Withdrawal(address member, uint256 dividend);

    /// @notice Address of the previous owner, the one that decided to fractionalized the NFT.
    function curator() virtual external view returns (address);

    /// @notice Mint ERC-20 tokens, ergo token ownership, by providing ownership deeds.
    function mint(bytes calldata deeds, bytes calldata signature) virtual external;

    /// @notice Returns whether this NFT vault has already been sold out. 
    function soldOut() virtual external view returns (bool);

    /// @notice Withdraw paid value in proportion to number of shares.
    /// @dev Fails if not yet sold out. 
    function withdraw() virtual external returns (uint256);

    /// @notice Tells withdrawable amount in weis from given address.
    /// @dev Returns 0 in all cases while not yet sold out. 
    function withdrawableFrom(address from) virtual external view returns (uint256);
}