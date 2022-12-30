    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "witnet-solidity-bridge/contracts/UsingWitnet.sol";
import "witnet-solidity-bridge/contracts/patterns/Clonable.sol";

import "./ITokenVault.sol";

abstract contract ITokenVaultWitnet
    is
        Clonable,
        ITokenVault,
        UsingWitnet
{
    enum Redemption {
        Unknown,
        Awaiting,
        Failed,
        Rejected,
        Accepted
    }

    function mint() virtual external returns (uint256);
    function mintableFrom(address from) virtual external view returns (uint256);

    function redeem(bytes calldata deeds) virtual external payable;
    function redemptionOf(address from) virtual external view returns (Redemption);
}