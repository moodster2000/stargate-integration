// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interfaces/IRemoteCreatureBoringToken.sol";

/// @title RemoteCreatureBoringFactory - Factory contract for remote chains
/// @notice This contract manages the creation of remote CreatureBoring tokens
/// @dev Simplified version for manually creating tokens on remote chains
contract RemoteCreatureBoringFactory is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// @notice Address of the token implementation contract
    address public tokenImplementation;
    
    /// @notice Mapping to verify if an address is a valid CreatureBoring token
    mapping(address => bool) public isCreatureBoringToken;
    
    /// @notice Home chain EID
    uint32 public homeChainEid;
    
    /// @notice LayerZero endpoint address
    address public lzEndpoint;
    
    /// @notice Stargate router address
    address public stargateRouter;

    /// @notice Emitted when a new token is created
    event TokenCreated(
        address tokenAddress,
        string name,
        string symbol,
        address homeTokenAddress
    );
    
    /// @notice Emitted when token implementation is updated
    event TokenImplementationUpdated(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the RemoteCreatureBoringFactory contract
    /// @param _tokenImplementation Address of the token implementation contract
    /// @param _homeChainEid EID of the home chain
    /// @param _lzEndpoint Address of the LayerZero endpoint
    /// @param _stargateRouter Address of the Stargate router
    function initialize(
        address _tokenImplementation,
        uint32 _homeChainEid,
        address _lzEndpoint,
        address _stargateRouter
    ) external initializer {
        require(_tokenImplementation != address(0), "Invalid implementation");
        require(_homeChainEid != 0, "Invalid home chain EID");
        require(_lzEndpoint != address(0), "Invalid LZ endpoint");
        require(_stargateRouter != address(0), "Invalid stargate router");
        
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        tokenImplementation = _tokenImplementation;
        homeChainEid = _homeChainEid;
        lzEndpoint = _lzEndpoint;
        stargateRouter = _stargateRouter;
    }
    
    /// @notice Creates a new remote CreatureBoring token
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param homeTokenAddress Address of the token on the home chain
    /// @return address of the newly created token
    function createRemoteToken(
        string memory name,
        string memory symbol,
        address homeTokenAddress
    ) external onlyOwner nonReentrant whenNotPaused returns (address) {
        require(homeTokenAddress != address(0), "Invalid home token address");
        
        // Prepare initialization data for token
        bytes memory initData = abi.encodeWithSelector(
            IRemoteCreatureBoringToken.initialize.selector,
            name,
            symbol,
            homeTokenAddress,
            homeChainEid,
            lzEndpoint,
            stargateRouter
        );
        
        // Deploy proxy that points to the token implementation
        ERC1967Proxy proxy = new ERC1967Proxy(
            tokenImplementation,
            initData
        );
        
        address tokenAddress = address(proxy);
        
        // Register token in factory
        isCreatureBoringToken[tokenAddress] = true;
        
        // Transfer ownership of token to factory owner
        IRemoteCreatureBoringToken(payable(tokenAddress)).transferOwnership(owner());
        
        emit TokenCreated(tokenAddress, name, symbol, homeTokenAddress);
        
        return tokenAddress;
    }
    
    /// @notice Updates the token implementation address
    /// @param _newImplementation New token implementation address
    /// @dev Only callable by owner
    function setTokenImplementation(address _newImplementation) external onlyOwner {
        require(_newImplementation != address(0), "Invalid implementation");
        address oldImplementation = tokenImplementation;
        tokenImplementation = _newImplementation;
        emit TokenImplementationUpdated(oldImplementation, _newImplementation);
    }
    
    /// @notice Update home chain EID
    /// @param _homeChainEid New home chain EID
    function setHomeChainEid(uint32 _homeChainEid) external onlyOwner {
        require(_homeChainEid != 0, "Invalid home chain EID");
        homeChainEid = _homeChainEid;
    }
    
    /// @notice Set LayerZero endpoint address
    /// @param _lzEndpoint New LayerZero endpoint address
    function setLzEndpoint(address _lzEndpoint) external onlyOwner {
        require(_lzEndpoint != address(0), "Invalid LZ endpoint");
        lzEndpoint = _lzEndpoint;
    }
    
    /// @notice Set Stargate router address
    /// @param _stargateRouter New Stargate router address
    function setStargateRouter(address _stargateRouter) external onlyOwner {
        require(_stargateRouter != address(0), "Invalid stargate router");
        stargateRouter = _stargateRouter;
    }

    /// @notice Pauses factory operations
    /// @dev Only callable by owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses factory operations
    /// @dev Only callable by owner
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /// @notice Function that authorizes upgrades
    /// @dev Only callable by owner as enforced by OwnableUpgradeable
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}