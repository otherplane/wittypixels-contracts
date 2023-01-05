// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
    using Strings for uint256;
    using WittyPixels for bytes;
    using WittyPixels for bytes32[];
    using WittyPixels for WittyPixels.ERC721Token;

    WitnetRequestTemplate immutable public witnetRequestImageDigest;
    WitnetRequestTemplate immutable public witnetRequestTokenRoots;
    WittyPixels.TokenStorage internal __storage;

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

    modifier tokenInStatus(uint256 _tokenId, WittyPixels.ERC721TokenStatus _status) {
        require(getTokenStatus(_tokenId) == _status, "WittyPixelsToken: bad mood");
        _;
    }

    constructor(
            WitnetRequestTemplate _requestImageDigest,
            WitnetRequestTemplate _requestTokenRoots,
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
        assert(address(_requestTokenRoots) != address(0));
        witnetRequestImageDigest = _requestImageDigest;
        witnetRequestTokenRoots = _requestTokenRoots;
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
            // a proxy is beining initilized for the first time ...
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
        return string(abi.encodePacked(
            baseURI(),
            "metadata/",
            block.chainid.toString(),
            "/",
            _tokenId.toString()
        ));
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
    /// @notice of ERC-20 ERC721Token Vault. 
    /// @dev Caller must be the owner of specified token.
    /// @param _tokenId ERC721Token identifier within that collection.
    /// @param _tokenVaultSettings Extra settings to be passed when initializing the token vault contract.
    function fractionalize(
            uint256 _tokenId,
            bytes   memory _tokenVaultSettings
        )
        external
        tokenExists(_tokenId)
        returns (ITokenVault)
    {
        // check required conditions
        require(
            address(__storage.tokenVaultPrototype) != address(0),
            "WittyPixelsToken: no token vault prototype"
        );
        require(
            ownerOf(_tokenId) == msg.sender,
            "WittyPixelsToken: not the token owner"
        );
        require(
            __storage.tokenVaultIndex[_tokenId] == 0,
            "WittyPixelsToken: already fractionalized"
        );
        
        // clone token vault prototype and initialize cloned instance
        IWittyPixelsTokenVault _tokenVault = IWittyPixelsTokenVault(address(
            __storage.tokenVaultPrototype.cloneAndInitialize(abi.encode(
                WittyPixels.TokenVaultInitParams({
                    curator: msg.sender,
                    name: string(abi.encode(name(), " #", _tokenId.toString())),
                    symbol: symbol(),
                    supply: 10 ** 18,
                    settings: _tokenVaultSettings,
                    tokenId: _tokenId
                })
            ))
        ));

        // store token vault contract
        uint _tokenVaultIndex = ++ __storage.totalTokenVaults;
        __storage.vaults[_tokenVaultIndex] = _tokenVault;

        // update reference to token vault contract in token's metadata
        __storage.tokenVaultIndex[_tokenId] = _tokenVaultIndex;

        // emits event
        emit Fractionalized(
            msg.sender,
            address(this),
            _tokenId,
            _tokenVaultIndex,
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
            try _vault.soldOut() returns (bool _soldOut) {
                return (_soldOut
                    ? ITokenVaultFactory.TokenVaultStatus.SoldOut
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

    /// @notice Returns base URI for all tokens of this collection.
    function baseURI()
        public view
        override
        returns (string memory)
    {
        return __storage.baseURI;
    }

    /// @notice Gets token's current status.
    function getTokenStatus(uint256 tokenId)
        public view
        override
        returns (WittyPixels.ERC721TokenStatus)
    {
        if (tokenId > __storage.totalSupply && tokenId > 0) {
            WittyPixels.ERC721Token storage __metadata = __storage.items[tokenId];
            if (__metadata.block > 0) {
                uint _vaultIndex = __storage.tokenVaultIndex[tokenId];
                if (_vaultIndex > 0) {
                    if (ownerOf(tokenId) != address(__storage.vaults[_vaultIndex])) {
                        return WittyPixels.ERC721TokenStatus.SoldOut;
                    } else {
                        return WittyPixels.ERC721TokenStatus.Fractionalized;
                    }
                } else {
                    return WittyPixels.ERC721TokenStatus.Minted;
                }
            } else {
                return WittyPixels.ERC721TokenStatus.Minting;
            }
        } else {
            return WittyPixels.ERC721TokenStatus.Void;
        }
    }

    /// @notice Gets token ERC721Token.
    function getTokenMetadata(uint256 _tokenId)
        external view
        override
        tokenExists(_tokenId)
        returns (WittyPixels.ERC721Token memory)
    {
        return __storage.items[_tokenId];
    }
    
    /// @notice Gets token vault contract, if any.
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

    /// @notice Gets set of immutable contracts that were used for
    /// @notice retrieving token's metadata and image digest from 
    /// @notice the Witnet oracle.
    function getTokenWitnetRequests(uint256 _tokenId)
        external view
        override
        tokenExists(_tokenId)
        returns (WittyPixels.ERC721TokenWitnetRequests memory)
    {
        return __storage.witnetRequests[_tokenId];
    }

    /// @notice Serialize token ERC721Token to JSON string.
    function metadata(uint256 _tokenId)
        external view 
        override
        tokenExists(_tokenId)
        returns (string memory)
    {
        return __storage.items[_tokenId].toJSON();
    }

    /// @notice Returns total number of WittyPixels tokens that have been minted so far.
    function totalSupply()
        external view
        override
        returns (uint256)
    {
        return __storage.totalSupply;
    }

    function verifyTokenPlayerScore(
            uint256 _tokenId,
            uint256 _playerIndex,
            uint256 _playerScore,
            bytes32[] memory _proof
        )
        external view
        override
        tokenExists(_tokenId)
        returns (bool)
    {
        WittyPixels.ERC721Token storage __metadata = __storage.items[_tokenId];
        return (
            _playerIndex < __metadata.theStats.totalPlayers
                && _proof.merkle(keccak256(abi.encode(
                    _playerIndex,
                    _playerScore
                ))) == __metadata.theRoots.scores
        );
    }

    function verifyTokenPlayerName(
            uint256 _tokenId,
            uint256 _playerIndex,
            string calldata _playerName,
            bytes32[] calldata _proof
        )
        external view
        override
        tokenExists(_tokenId)
        returns (bool)
    {
        WittyPixels.ERC721Token storage __metadata = __storage.items[_tokenId];
        return (
            _playerIndex < __metadata.theStats.totalPlayers
                && _proof.merkle(keccak256(abi.encode(
                    _playerIndex,
                    _playerName
                ))) == __metadata.theRoots.scores
        );
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsTokenAdmin' -----------------------------------------------------------------

    function premint(
            uint256 _tokenId,
            bytes32 _slaHash,
            string calldata _imageURI
        )
        external payable
        override
        onlyOwner
        nonReentrant
        initialized
    {
        WittyPixels.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        require(
            _status == WittyPixels.ERC721TokenStatus.Void && _tokenId == __storage.totalSupply + 1
                || _status == WittyPixels.ERC721TokenStatus.Minting,
            "WittyPixelsToken: bad mood"
        );
        require(
            bytes(_imageURI).length > 0,
            "WittyPixelsToken: no image URI"
        );        
        if (_status == WittyPixels.ERC721TokenStatus.Void) {
            // increase total supply only upon first premint of this token id:
            __storage.totalSupply ++;
        }
        WittyPixels.ERC721Token storage __metadata = __storage.items[_tokenId];        
        WittyPixels.ERC721TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];
        
        // Ask Witnet to confirm the token's image URI actually exists:
        uint _usedFunds;
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = _imageURI;
            __requests.imageDigest = WitnetRequestTemplate(payable(address(witnetRequestImageDigest.clone())));
            __requests.imageDigest.initialize(abi.encode(
                WitnetRequestTemplate.InitData({
                    args: _args,
                    slaHash: _slaHash
                })
            ));
            __metadata.imageURI = _imageURI;
            _usedFunds += __requests.imageDigest.post{value: msg.value}();
        }

        // Ask Witnet to retrieve token's metadata roots from the token base uri provider:
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = string(abi.encodePacked(
                bytes(baseURI()),
                "roots/",
                block.chainid.toString(),
                "/",
                _tokenId.toString()                
            ));
            __requests.tokenRoots = WitnetRequestTemplate(payable(address(witnetRequestTokenRoots.clone())));
            __requests.tokenRoots.initialize(abi.encode(WitnetRequestTemplate.InitData({
                args: _args,
                slaHash: _slaHash
            })));
            _usedFunds += __requests.imageDigest.post{value: msg.value - _usedFunds}();
        }

        // Transfer back unused funds, if any:
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }

        emit Minting(_tokenId, baseURI(), _imageURI, _slaHash);
    }    

    function mint(
            uint256 _tokenId,
            WittyPixels.ERC721TokenEvent memory _theEvent,
            WittyPixels.ERC721TokenCanvas memory _theCanvas,
            WittyPixels.ERC721TokenStats memory _theStats
        )
        external
        onlyOwner
        nonReentrant
        tokenInStatus(_tokenId, WittyPixels.ERC721TokenStatus.Minting)
    {
        WittyPixels.ERC721Token storage __metadata = __storage.items[_tokenId];
        WittyPixels.ERC721TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];
        
        bool _resultOk; bytes memory _resultBytes;        
        // Check the image URI actually exists, and store image digest hash, 
        // as provided by the Witnet oracle:
        {
            (_resultOk, _resultBytes) = __requests.imageDigest.read();
            require(_resultOk, "WittyPixelsToken: image digest failed");
            __metadata.block = block.number;
            __metadata.imageDigest = _resultBytes.toBytes32();
        }

        // Check the token data root reported by Witnet matches the rest of token's
        // metadata, including the image digest:
        {
            (_resultOk, _resultBytes) = __requests.tokenRoots.read();
            require(_resultOk, "WittyPixelsToken: token roots failed");
            WittyPixels.ERC721TokenRoots memory _roots = abi.decode(_resultBytes, (WittyPixels.ERC721TokenRoots));
            require(
                keccak256(abi.encode(
                    __metadata.imageDigest,
                    _theEvent,
                    _theCanvas,
                    _theStats,
                    _roots.names,
                    _roots.scores
                )) == _roots.data,
                "WittyPixelsToken: token roots mistmatch"
            );
            __metadata.theRoots = _roots;
        }
        
        // Check the event data:
        {
            require(
                bytes(_theEvent.name).length > 0
                    && bytes(_theEvent.venue).length > 0,
                "WittyPixelsToken: event empty strings"
            );
            require(
                _theEvent.startTs <= _theEvent.endTs,
                "WittyPixelsToken: event bad timestamps"
            );
            __metadata.theEvent = _theEvent;
        }
        
        // Set the token's canvas and game stats:
        {
            __metadata.theCanvas = _theCanvas;
            __metadata.theStats = _theStats;
        }

        // Mint the actual ERC-721 token:
        _safeMint(msg.sender, _tokenId);
    }

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata _uri)
        external 
        override
        onlyOwner
        initialized
    {
        __storage.baseURI = WittyPixels.checkBaseURI(_uri);
    }

    /// @notice Update sponsors access-list by adding new members. 
    /// @dev If already included in the list, names could still be updated.
    function setTokenSponsors(
            uint256 _tokenId,
            address[] calldata _addresses,
            string[] calldata _texts
        )
        external
        override
        onlyOwner
        initialized
    {
        assert(_addresses.length == _texts.length);
        // tokenId can only be current totalSupply + 1: not minted, and not in the process of being minted
        require(
            _tokenId == __storage.totalSupply + 1,
            "WittyPixelsToken: invalid token"
        );
        // add new sponsor addresses to the access list if not yet there:
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
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

    /// @notice Vault logic contract to be used in next fractions.
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address _prototype)
        external
        override
        onlyOwner
        initialized
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
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        if (_index < __sponsors.addresses.length) {
            _sponsor = __sponsors.addresses[_index];
            WittyPixels.ERC721TokenJackpot storage __jackpot = __sponsors.jackpots[_sponsor];
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
        tokenInStatus(_tokenId, WittyPixels.ERC721TokenStatus.Void)
    {
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
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
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        assert(_index < __sponsors.addresses.length);
        address _sponsor = __sponsors.addresses[_index];
        WittyPixels.ERC721TokenJackpot storage __jackpot = __sponsors.jackpots[_sponsor];
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
        WittyPixels.TokenInitParams memory _params = abi.decode(
            _initdata,
            (WittyPixels.TokenInitParams)
        );
        __storage.baseURI = WittyPixels.checkBaseURI(_params.baseURI);
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