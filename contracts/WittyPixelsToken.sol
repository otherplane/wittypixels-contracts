// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "witnet-solidity-bridge/contracts/impls/WitnetProxy.sol";
import "witnet-solidity-bridge/contracts/interfaces/IWitnetRequest.sol";
import "witnet-solidity-bridge/contracts/patterns/Clonable.sol";

import "./interfaces/ITokenVaultFactory.sol";
import "./interfaces/IWittyPixelsToken.sol";
import "./interfaces/IWittyPixelsTokenAdmin.sol";
import "./interfaces/IWittyPixelsTokenJackpots.sol";

import "./patterns/WittyPixelsUpgradeableBase.sol";

/// @title  Witty Pixels NFT - ERC721 token contract
/// @author Otherplane Labs Ltd., 2022
/// @dev    This contract needs to be proxified.
contract WittyPixelsToken
    is
        ERC721Upgradeable,
        ITokenVaultFactory,
        IWittyPixelsToken,
        IWittyPixelsTokenAdmin,
        IWittyPixelsTokenJackpots,
        WittyPixelsUpgradeableBase
{
    using ERC165Checker for address;
    using WittyPixelsLib for bytes;
    using WittyPixelsLib for bytes32[];
    using WittyPixelsLib for uint256;
    using WittyPixelsLib for WittyPixelsLib.ERC721Token;

    WitnetRequestTemplate immutable public witnetRequestImageDigest;
    WitnetRequestTemplate immutable public witnetRequestTokenStats;

    WittyPixelsLib.TokenStorage internal __storage;

    modifier initialized {
        require(
            __storage.implementation != address(0),
            "WittyPixelsToken: not initialized"
        );
        _;
    }

    modifier onlyTokenSponsors(uint256 _tokenId) {
        require(
            __storage.sponsors[_tokenId].jackpots[msg.sender].authorized,
            "WittyPixelsToken: not authorized"
        );
        _;
    }

    modifier tokenExists(uint256 _tokenId) {
        require(
            _exists(_tokenId),
            "WittyPixelsToken: unknown token"
        );
        _;
    }

    modifier tokenInStatus(uint256 _tokenId, WittyPixelsLib.ERC721TokenStatus _status) {
        require(getTokenStatus(_tokenId) == _status, "WittyPixelsToken: bad mood");
        _;
    }

    constructor(
            WitnetRequestTemplate _requestImageDigest,
            WitnetRequestTemplate _requestTokenStats,
            bool _upgradable,
            bytes32 _version
        )
        WittyPixelsUpgradeableBase(
            _upgradable,
            _version,
            "art.wittypixels.token"
        )
    {
        assert(address(_requestImageDigest) != address(0));
        assert(address(_requestTokenStats) != address(0));
        witnetRequestImageDigest = _requestImageDigest;
        witnetRequestTokenStats = _requestTokenStats;
    }


    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      onlyDelegateCalls
      returns (bool)
    {
        return _interfaceId == type(ITokenVaultFactory).interfaceId
            || _interfaceId == type(IWittyPixelsToken).interfaceId
            || _interfaceId == type(IWittyPixelsTokenJackpots).interfaceId
            || ERC721Upgradeable.supportsInterface(_interfaceId)
            || _interfaceId == type(Ownable2StepUpgradeable).interfaceId
            || _interfaceId == type(Upgradeable).interfaceId
            || _interfaceId == type(IWittyPixelsTokenAdmin).interfaceId
        ;
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initdata) 
        public
        virtual override
        onlyDelegateCalls // => we don't want the logic base contract to be ever initialized
    {
        address _implementation = __storage.implementation;
        if (_implementation == address(0)) {
            // a proxy is being initilized for the first time ...
            _initializeProxy(_initdata);
        }
        else {
            // a proxy is being upgraded ...
            // only the proxy's owner can upgrade it
            require(
                msg.sender == owner(),
                "WittyPixelsToken: not the owner"
            );
            // the implementation cannot be upgraded more than once, though
            require(
                _implementation != base(),
                "WittyPixelsToken: already initialized"
            );
            emit Upgraded(
                msg.sender,
                base(),
                codehash(),
                version()
            );
        }
        __storage.implementation = base();    
    }

    
    // ================================================================================================================
    // --- Overrides 'ERC721TokenMetadata' overriden functions --------------------------------------------------------

    function tokenURI(uint256 _tokenId)
        public view
        virtual override
        tokenExists(_tokenId)
        returns (string memory)
    {
        return WittyPixelsLib.tokenMetadataURI(_tokenId, __storage.items[_tokenId].baseURI);
    }


    // ================================================================================================================
    // --- Implementation of 'ITokenVaultFactory' ---------------------------------------------------------------------

    /// @notice Fractionalize given token by transferring ownership to new instance of ERC-20 ERC721Token Vault. 
    /// @dev This vault factory is only intended for fractionalizing its own tokens.
    function fractionalize(address, uint256, bytes memory)
        external pure
        override
        returns (ITokenVault)
    {
        revert("WittyPixelsToken: not implemented");
    }

    /// @notice Fractionalize given token by transferring ownership to new instance
    /// @notice of the ERC721 Token Vault prototype contract. 
    /// @dev Token must be in 'Minting' status and involved Witnet requests successfully solved.
    /// @param _tokenId ERC721Token identifier within that collection.
    /// @param _tokenVaultSettings Extra settings to be passed when initializing the token vault contract.
    function fractionalize(
            uint256 _tokenId,
            bytes   memory _tokenVaultSettings
        )
        external
        tokenInStatus(_tokenId, WittyPixelsLib.ERC721TokenStatus.Minting)
        onlyOwner
        returns (ITokenVault)
    {
        WittyPixelsLib.ERC721Token storage __token = __storage.items[_tokenId];
        WittyPixelsLib.ERC721TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];
        
        // Check there's a token vault prototype set:
        require(
            address(__storage.tokenVaultPrototype) != address(0),
            "WittyPixelsToken: no token vault prototype"
        );

        // Check the image URI actually exists, and store the image digest:
        try __requests.imageDigest.lastValue()
            returns (bytes memory, bytes32 _txhash, uint256 _txts)
        {
            require(
                _txts >= __token.birthTs,
                "WittyPixelsToken: anachronic image proof"
            );
            __token.imageWitnetTxHash = _txhash;
        }
        catch Error(string memory _reason) {
            revert(_reason);
        }
        catch (bytes memory) {
            revert("WittyPixelsToken: cannot deserialize image proof");
        }

        // Check the token roots reported by Witnet match the rest of token's
        // metadata, including the image digest:
        try __requests.tokenStats.lastValue()
            returns (bytes memory _stats, bytes32 _txhash, uint256 _txts)
        {
            require(
                _txts >= __token.birthTs,
                "WittyPixelsToken: anachronic stats proof"
            );
            __token.statsWitnetTxHash = _txhash;
            __token.theStats = abi.decode(_stats, (WittyPixelsLib.ERC721TokenStats));
        }
        catch Error(string memory _reason) {
            revert(_reason);
        }
        catch (bytes memory) {
            revert("WittyPixelsToken: cannot deserialize stats proof");
        }
        
        // Clone the token vault prototype and initialize the cloned instance:
        IWittyPixelsTokenVault _tokenVault = IWittyPixelsTokenVault(address(
            __storage.tokenVaultPrototype.cloneAndInitialize(abi.encode(
                WittyPixelsLib.TokenVaultInitParams({
                    curator: msg.sender,
                    name: string(abi.encodePacked(
                        name(),
                        bytes(" #"),
                        _tokenId.toString()
                    )),
                    symbol: symbol(),
                    settings: _tokenVaultSettings,
                    token: address(this),
                    tokenId: _tokenId,
                    tokenPixels: __token.theStats.canvasPixels
                })
            ))
        ));

        // Store token vault contract:
        uint _tokenVaultIndex = ++ __storage.totalTokenVaults;
        __storage.vaults[_tokenVaultIndex] = _tokenVault;

        // Update reference to token vault contract in token's metadata
        __storage.tokenVaultIndex[_tokenId] = _tokenVaultIndex;

        // Mint the actual ERC-721 token and set the just created vault contract as first owner ever:
        _mint(address(_tokenVault), _tokenId);
        
        // Increment total supply:
        __storage.totalSupply ++;

        // Emits event
        emit Fractionalized(
            msg.sender,
            address(this),
            _tokenId,
            address(_tokenVault)
        );

        return ITokenVault(address(_tokenVault));
    }

    /// @notice Gets data of a token vault created by this factory.
    function getTokenVaultByIndex(uint256 index)
        public view
        override
        returns (ITokenVault)
    {
        if (index < __storage.totalTokenVaults) {
            return ITokenVault(__storage.vaults[index]);
        } else {
            return ITokenVault(address(0));
        }
    }
    
    /// @notice Gets current status of token vault created by this factory.
    function getTokenVaultStatusByIndex(uint256 index)
        external view
        returns (TokenVaultStatus)
    {
        ITokenVault _vault = getTokenVaultByIndex(index);
        if (address(_vault) != address(0)) {
            try _vault.acquired() returns (bool _acquired) {
                return (_acquired
                    ? ITokenVaultFactory.TokenVaultStatus.Acquired
                    : ITokenVaultFactory.TokenVaultStatus.Active
                );
            } catch {
                return ITokenVaultFactory.TokenVaultStatus.Deleted;
            }
        } else {
            return ITokenVaultFactory.TokenVaultStatus.Unknown;
        }
    }

    /// @notice Returns token vault prototype being instantiated when fractionalizing. 
    /// @dev If destructible, it must be owned by this contract.
    function tokenVaultPrototype()
        external view
        override
        returns (ITokenVault)
    {
        return ITokenVault(__storage.tokenVaultPrototype);
    }

    /// @notice Returns number of vaults created so far.
    function totalTokenVaults()
        external view
        override 
        returns (uint256)
    {
        return __storage.totalTokenVaults;
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsToken' ----------------------------------------------------------------------

    /// @notice Returns base URI to be used by upcoming tokens of this collection.
    function baseURI()
        override public view
        initialized
        returns (string memory)
    {
        return __storage.baseURI;
    }

    /// @notice Returns status of given WittyPixels token.
    /// @dev Possible values:
    /// @dev - 0 => Unknown, not yet launched
    /// @dev - 1 => Launched: info about the corresponding WittyPixels events has been provided by the collection's owner
    /// @dev - 2 => Minting: the token is being minted, awaiting for external data to be retrieved by the Witnet Oracle.
    /// @dev - 3 => Fracionalized: the token has been minted and its ownership transfered to a WittyPixelsTokenVault contract.
    /// @dev - 4 => Acquired: token's ownership has been acquired and belongs to the WittyPixelsTokenVault no more. 
    function getTokenStatus(uint256 _tokenId)
        override public view
        initialized
        returns (WittyPixelsLib.ERC721TokenStatus)
    {
        if (_tokenId <= __storage.totalSupply) {
            uint _vaultIndex = __storage.tokenVaultIndex[_tokenId];
            if (
                _vaultIndex > 0
                    && ownerOf(_tokenId) != address(__storage.vaults[_vaultIndex])
            ) {
                return WittyPixelsLib.ERC721TokenStatus.Acquired;
            } else {
                return WittyPixelsLib.ERC721TokenStatus.Fractionalized;
            }
        } else {
            WittyPixelsLib.ERC721Token storage __token = __storage.items[_tokenId];
            if (__token.birthTs > 0) {
                return WittyPixelsLib.ERC721TokenStatus.Minting;
            } else if (bytes(__token.theEvent.name).length > 0) {
                return WittyPixelsLib.ERC721TokenStatus.Launching;
            } else {
                return WittyPixelsLib.ERC721TokenStatus.Void;
            }
        }
    }

    /// @notice Returns literal string representing current status of given WittyPixels token.    
    function getTokenStatusString(uint256 _tokenId)
        override external view
        initialized
        returns (string memory)
    {
        WittyPixelsLib.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        if (_status == WittyPixelsLib.ERC721TokenStatus.Acquired) {
            return "Acquired";
        } else if (_status == WittyPixelsLib.ERC721TokenStatus.Fractionalized) {
            return "Fractionalized";
        } else if (_status == WittyPixelsLib.ERC721TokenStatus.Minting) {
            return "Minting";
        } else if (_status == WittyPixelsLib.ERC721TokenStatus.Launching) {
            return "Launching";
        } else {
            return "Void";
        }
    }

    /// @notice Returns WittyPixels token metadata of given token.
    function getTokenMetadata(uint256 _tokenId)
        external view
        override
        initialized
        returns (WittyPixelsLib.ERC721Token memory)
    {
        return __storage.items[_tokenId];
    }
    
    /// @notice Returns WittyPixelsTokenVault instance bound to the given token.
    /// @dev Reverts if the token has not yet been fractionalized.
    function getTokenVault(uint256 _tokenId)
        public view
        override
        tokenExists(_tokenId)
        returns (ITokenVaultWitnet)
    {
        return __storage.vaults[
            __storage.tokenVaultIndex[_tokenId]
        ];
    }

    /// @notice Returns set of Witnet data requests involved in the minting process.
    /// @dev Returns zero addresses if the token is yet in 'Unknown' or 'Launched' status.
    function getTokenWitnetRequests(uint256 _tokenId)
        external view
        override
        initialized
        returns (WittyPixelsLib.ERC721TokenWitnetRequests memory)
    {
        return __storage.witnetRequests[_tokenId];
    }

    /// @notice Returns image URI of given token.
    function imageURI(uint256 _tokenId)
        override
        external view 
        initialized
        returns (string memory)
    {
        WittyPixelsLib.ERC721TokenStatus _tokenStatus = getTokenStatus(_tokenId);
        if (_tokenStatus == WittyPixelsLib.ERC721TokenStatus.Void) {
            return string(hex"");
        } else {
            return WittyPixelsLib.tokenImageURI(
                _tokenId,
                _tokenStatus == WittyPixelsLib.ERC721TokenStatus.Launching
                    ? baseURI()
                    : __storage.items[_tokenId].baseURI
            );
        }
    }

    /// @notice Serialize token ERC721Token to JSON string.
    function metadata(uint256 _tokenId)
        external view 
        override
        tokenExists(_tokenId)
        returns (string memory)
    {
        return __storage.items[_tokenId].toJSON(
            _tokenId,
            __storage.witnetRequests[_tokenId].tokenStats.retrievalHash()
        );
    }

    /// @notice Returns number of pixels within the WittyPixels Canvas of given token.
    function pixelsOf(uint256 _tokenId)
        virtual override
        external view
        returns (uint256)
    {
        return __storage.items[_tokenId].theStats.totalPixels;
    }

    /// @notice Returns number of pixels contributed to given WittyPixels Canvas by given address.
    /// @dev Every WittyPixels player needs to claim contribution to a WittyPixels Canvas by calling 
    /// @dev to the `redeem(bytes deeds)` method on the corresponding token's vault contract.
    function pixelsFrom(uint256 _tokenId, address _from)
        virtual override
        external view
        returns (uint256)
    {
        IWittyPixelsTokenVault _vault = IWittyPixelsTokenVault(address(getTokenVault(_tokenId)));
        return (address(_vault) != address(0)
            ? _vault.pixelsOf(_from)
            : 0
        );
    }

    /// @notice Count NFTs tracked by this contract.
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///         them has an assigned and queryable owner not equal to the zero address
    function totalSupply()
        external view
        override
        returns (uint256)
    {
        return __storage.totalSupply;
    }

    /// @notice Verifies the provided Merkle Proof matches the token's authorship's root that
    /// @notice was retrieved by the Witnet Oracle upon minting of given token. 
    /// @dev Reverts if the token has not yet been fractionalized.
    function verifyTokenAuthorship(
            uint256 _tokenId,
            uint256 _playerIndex,
            uint256 _playerPixels,
            bytes32[] memory _proof
        )
        external view
        override
        tokenExists(_tokenId)
        returns (bool)
    {
        WittyPixelsLib.ERC721Token storage __token = __storage.items[_tokenId];
        return (
            _playerIndex < __token.theStats.totalPlayers
                && _proof.merkle(keccak256(abi.encode(
                    _playerIndex,
                    _playerPixels
                ))) == __token.theStats.authorshipsRoot
        );
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsTokenAdmin' -----------------------------------------------------------------

    function launch(WittyPixelsLib.ERC721TokenEvent calldata _theEvent)
        override external
        onlyOwner
        returns (uint256 _tokenId)
    {
        _tokenId = __storage.totalSupply + 1;
        WittyPixelsLib.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        require(
            _status == WittyPixelsLib.ERC721TokenStatus.Void
                || _status == WittyPixelsLib.ERC721TokenStatus.Launching,
            "WittyPixelsToken: bad mood"
        );
        // Check the event data:
        require(
            bytes(_theEvent.name).length > 0
                && bytes(_theEvent.venue).length > 0,
            "WittyPixelsToken: event empty strings"
        );
        require(
            _theEvent.startTs <= _theEvent.endTs,
            "WittyPixelsToken: event bad timestamps"
        );
        // Change token status:
        __storage.items[_tokenId].theEvent = _theEvent;
    }
    
    function mint(
            uint256 _tokenId,
            bytes32 _witnetSlaHash
        )
        override external payable
        onlyOwner 
        nonReentrant
    {
        WittyPixelsLib.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        require(
            _status == WittyPixelsLib.ERC721TokenStatus.Launching
                || _status == WittyPixelsLib.ERC721TokenStatus.Minting,
            "WittyPixelsToken: bad mood"
        );        
        WittyPixelsLib.ERC721Token storage __token = __storage.items[_tokenId];
        require(
            block.timestamp >= __token.theEvent.endTs,
            "WittyPixelsToken: the event is not over yet"
        );
        
        // Set the token's base uri and inception timestamp
        string memory _currentBaseURI = __storage.baseURI;
        string memory _imageuri = WittyPixelsLib.tokenImageURI(_tokenId, _currentBaseURI);
        {
            __token.baseURI = _currentBaseURI;
            __token.birthTs = block.timestamp;            
        }

        uint _usedFunds; WitnetRequestTemplate _request;
        WittyPixelsLib.ERC721TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];        
        // Ask Witnet to confirm the token's image URI actually exists:
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = _imageuri;
            _request = witnetRequestImageDigest.clone(
                abi.encode(WitnetRequestTemplate.InitData({
                    args: _args,
                    slaHash: _witnetSlaHash
                }))
            );
            _usedFunds += _request.update{value: msg.value / 2}();
            __requests.imageDigest = _request;
        }

        // Ask Witnet to retrieve token's metadata stats from the token base uri provider:
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = WittyPixelsLib.tokenStatsURI(_tokenId, _currentBaseURI);
            _request = witnetRequestTokenStats.clone(
                abi.encode(WitnetRequestTemplate.InitData({
                    args: _args,
                    slaHash: _witnetSlaHash
                }))
            );
            _usedFunds += _request.update{value: msg.value / 2}();
            __requests.tokenStats = _request;
        }

        // Transfer back unused funds, if any:
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
        
        // Emit event:
        emit Minting(_tokenId, _imageuri, _witnetSlaHash);
    }

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata _uri)
        external 
        override
        onlyOwner 
    {
        __storage.baseURI = WittyPixelsLib.checkBaseURI(_uri);
    }

    /// @notice Update sponsors access-list by adding new players. 
    /// @dev If already included in the list, names could still be updated.
    function setTokenSponsors(
            uint256 _tokenId,
            address[] calldata _addresses,
            string[] calldata _texts
        )
        external
        override
        onlyOwner
    {
        assert(_addresses.length == _texts.length);
        // tokenId can only be current totalSupply + 1: not minted, and not in the process of being minted
        require(
            _tokenId == __storage.totalSupply + 1,
            "WittyPixelsToken: invalid token"
        );
        // add new sponsor addresses to the access list if not yet there:
        WittyPixelsLib.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        for (uint _i = 0; _i < _addresses.length; _i ++) {
            address _addr = _addresses[_i];
            if (!__sponsors.jackpots[_addr].authorized) {
                __sponsors.addresses.push(_addr);
                __sponsors.jackpots[_addr].authorized = true;
                emit NewTokenSponsor(
                    _tokenId,
                    __sponsors.addresses.length - 1,
                    _addr
                );
            }
            // update sponsor name in all cases
            __sponsors.jackpots[_addr].text = _texts[_i];
        }
    }

    /// @notice Vault logic contract to be used in next calls to `fractionalize(..)`. 
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address _prototype)
        external
        override
        onlyOwner
    {
        _verifyPrototypeCompliance(_prototype);
        __storage.tokenVaultPrototype = IWittyPixelsTokenVault(_prototype);
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsTokenJackpots' --------------------------------------------------------------

    function getTokenJackpotByIndex(
            uint256 _tokenId,
            uint256 _index
        )
        external view
        override
        returns (
            address _sponsor,
            address _winner,
            uint256 _value,
            string memory _text
        )
    {
        WittyPixelsLib.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        if (_index < __sponsors.addresses.length) {
            _sponsor = __sponsors.addresses[_index];
            WittyPixelsLib.ERC721TokenJackpot storage __jackpot = __sponsors.jackpots[_sponsor];
            _text = __jackpot.text;
            _value = __jackpot.value;
            _winner = __jackpot.winner;
        }
    }

    function getTokenJackpotsCount(uint256 _tokenId)
        external view
        override
        returns (uint256)
    {
        return __storage.sponsors[_tokenId].addresses.length;
    }

    function getTokenJackpotsTotalValue(uint256 _tokenId)
        external view
        override
        returns (uint256)
    {
        return __storage.sponsors[_tokenId].totalJackpots;
    }

    function sponsoriseToken(uint256 _tokenId)
        external payable
        override
        onlyTokenSponsors(_tokenId)
        tokenInStatus(_tokenId, WittyPixelsLib.ERC721TokenStatus.Void)
    {
        WittyPixelsLib.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        __sponsors.jackpots[msg.sender].value += msg.value;
        __sponsors.totalJackpots += msg.value;
    }

    function transferTokenJackpot(
            uint256 _tokenId,
            uint256 _index,
            address payable _winner
        )
        external
        override
        tokenExists(_tokenId)
        returns (uint256 _value)
    {
        require(
            getTokenVault(_tokenId).parentToken() == address(this),
            "WittyPixelsToken: unauthorized"
        );
        assert(_winner != address(0));
        WittyPixelsLib.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        assert(_index < __sponsors.addresses.length);
        address _sponsor = __sponsors.addresses[_index];
        WittyPixelsLib.ERC721TokenJackpot storage __jackpot = __sponsors.jackpots[_sponsor];
        require(
            __jackpot.winner == address(0), "WittyPixelsToken: already claimed"
        );
        _value = __jackpot.value;
        require(
            _value > 0,
            "WittyPixelsToken: no jackpot value"
        );
        require(
            _value < address(this).balance,
            "WittyPixelsToken: not enough balance"
        );
        __jackpot.value = 0;
        __jackpot.winner = _winner;
        _winner.transfer(_value);
        emit Jackpot(
            _tokenId, 
            _index,
            _winner,
            _value
        );
    }


    // ================================================================================================================
    // --- Internal virtual methods -----------------------------------------------------------------------------------

    function _initializeProxy(bytes memory _initdata)
        virtual internal
        initializer 
    {
        // As for OpenZeppelin's ERC721Upgradeable implementation,
        // name and symbol can only be initialized once;
        // as for an upgradable (and proxiable) contract as this one,
        // the setting of name and symbol needs to be invoked in
        // a dedicated and unique 'initializer' method, other from the
        // `initialize(bytes)` method that gets called every time
        // a proxy contract is upgraded.

        // read and set ERC721 initialization parameters
        WittyPixelsLib.TokenInitParams memory _params = abi.decode(
            _initdata,
            (WittyPixelsLib.TokenInitParams)
        );
        __storage.baseURI = WittyPixelsLib.checkBaseURI(_params.baseURI);
        __ERC721_init(
            _params.name,
            _params.symbol
        );        
        __Ownable2Step_init();
        __ReentrancyGuard_init();
    }

    function _verifyPrototypeCompliance(address _prototype) virtual internal view {
        require(
            _prototype.supportsInterface(type(IWittyPixelsTokenVault).interfaceId),
            "WittyPixelsToken: uncompliant prototype"
        );
    }

}