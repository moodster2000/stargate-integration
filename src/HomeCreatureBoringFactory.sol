// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interfaces/IOmniChainCreatureBoringToken.sol";

/// @title HomeCreatureBoringFactory - Factory contract for home chain
/// @notice This contract manages the creation of OmniChain CreatureBoring tokens on the home chain
/// @dev Extends the original factory with omnichain capabilities
contract HomeCreatureBoringFactory is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable 
{
    /// @notice Address where protocol fees are sent
    address public protocolFeeDestination;
    
    /// @notice Protocol fee percentages
    uint256 public protocolBuyFeePercent;
    uint256 public protocolSellFeePercent;
    
    /// @notice Address of the battle contract
    address public battleContract;
    
    /// @notice Address of the token implementation contract
    address public tokenImplementation;
    
    /// @notice Mapping to verify if an address is a valid CreatureBoring token
    mapping(address => bool) public isCreatureBoringToken;

    /// @notice Address that signs verification signatures
    address public signerAddress;
    
    /// @notice Endpoint for LayerZero messaging
    address public lzEndpoint;

    /// @notice Emitted when a new token is created
    event TokenCreated(
        address tokenAddress,
        string name,
        string symbol
    );
    
    /// @notice Emitted when protocol fee destination is updated
    event ProtocolFeeDestinationUpdated(
        address indexed oldDestination,
        address indexed newDestination
    );
    
    /// @notice Emitted when protocol buy fee percentage is updated
    event ProtocolBuyFeePercentUpdated(uint256 oldPercent, uint256 newPercent);
    
    /// @notice Emitted when protocol sell fee percentage is updated
    event ProtocolSellFeePercentUpdated(uint256 oldPercent, uint256 newPercent);
    
    /// @notice Emitted when token implementation is updated
    event TokenImplementationUpdated(
        address indexed oldImplementation,
        address indexed newImplementation
    );
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the HomeCreatureBoringFactory contract
    /// @param _protocolFeeDestination Address where protocol fees will be sent
    /// @param _protocolBuyFeePercent Protocol buy fee percentage
    /// @param _protocolSellFeePercent Protocol sell fee percentage
    /// @param _signerAddress Address used for verification signatures
    /// @param _tokenImplementation Address of the token implementation contract
    /// @param _lzEndpoint Address of the LayerZero endpoint
    function initialize(
        address _protocolFeeDestination,
        uint256 _protocolBuyFeePercent,
        uint256 _protocolSellFeePercent,
        address _signerAddress,
        address _tokenImplementation,
        address _lzEndpoint
    ) external initializer {
        require(_protocolFeeDestination != address(0), "Invalid fee destination");
        require(_signerAddress != address(0), "Invalid signer address");
        require(_tokenImplementation != address(0), "Invalid token implementation");
        require(_lzEndpoint != address(0), "Invalid LZ endpoint");
        
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        protocolFeeDestination = _protocolFeeDestination;
        protocolBuyFeePercent = _protocolBuyFeePercent;
        protocolSellFeePercent = _protocolSellFeePercent;
        signerAddress = _signerAddress;
        tokenImplementation = _tokenImplementation;
        lzEndpoint = _lzEndpoint;
    }



    /// @notice Sets the signer address for verification
    /// @param _signerAddress New signer address
    /// @dev Only callable by owner
    function setSignerAddress(address _signerAddress) external onlyOwner {
        require(_signerAddress != address(0), "Invalid signer address");
        signerAddress = _signerAddress;
    }

    /// @notice Sets the battle contract address
    /// @param _battleContract New battle contract address
    /// @dev Only callable by owner
    function setBattleContract(address _battleContract) external onlyOwner {
        require(_battleContract != address(0), "Invalid battle contract");
        battleContract = _battleContract;
    }

    /// @notice Updates the protocol fee destination
    /// @param _newDestination New fee destination address
    /// @dev Only callable by owner
    function setProtocolFeeDestination(address _newDestination) external onlyOwner {
        require(_newDestination != address(0), "Invalid address");
        address oldDestination = protocolFeeDestination;
        protocolFeeDestination = _newDestination;
        emit ProtocolFeeDestinationUpdated(oldDestination, _newDestination);
    }

    /// @notice Updates the protocol buy fee percentage
    /// @param _newPercent New buy fee percentage
    /// @dev Only callable by owner
    function setProtocolBuyFeePercent(uint256 _newPercent) external onlyOwner {
        uint256 oldPercent = protocolBuyFeePercent;
        protocolBuyFeePercent = _newPercent;
        emit ProtocolBuyFeePercentUpdated(oldPercent, _newPercent);
    }

    /// @notice Updates the protocol sell fee percentage
    /// @param _newPercent New sell fee percentage
    /// @dev Only callable by owner
    function setProtocolSellFeePercent(uint256 _newPercent) external onlyOwner {
        uint256 oldPercent = protocolSellFeePercent;
        protocolSellFeePercent = _newPercent;
        emit ProtocolSellFeePercentUpdated(oldPercent, _newPercent);
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
    
    /// @notice Set LayerZero endpoint address
    /// @param _lzEndpoint New LayerZero endpoint address
    function setLzEndpoint(address _lzEndpoint) external onlyOwner {
        require(_lzEndpoint != address(0), "Invalid LZ endpoint");
        lzEndpoint = _lzEndpoint;
    }

    /// @notice Creates a new OmniChain CreatureBoring token with proxy
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param homeChainEid The EID of this chain (home chain)
    /// @dev Only callable by owner, deploys a new proxy pointing to the implementation
    function createCreatureBoringToken(
        string memory name,
        string memory symbol,
        uint32 homeChainEid
    ) external onlyOwner nonReentrant whenNotPaused {
        // Prepare initialization data for token
        bytes memory initData = abi.encodeWithSelector(
            IOmniChainCreatureBoringToken.initialize.selector,
            name,
            symbol,
            protocolFeeDestination,
            protocolBuyFeePercent,
            protocolSellFeePercent,
            battleContract,
            signerAddress,
            lzEndpoint,
            homeChainEid,
            address(this)
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
        IOmniChainCreatureBoringToken(payable(tokenAddress)).transferOwnership(owner());
        
        emit TokenCreated(tokenAddress, name, symbol);
    }

    /// @notice Pauses token creation
    /// @dev Only callable by owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses token creation
    /// @dev Only callable by owner
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /// @notice Function that authorizes upgrades
    /// @dev Only callable by owner as enforced by OwnableUpgradeable
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    
    /// @notice Allows contract to receive ETH
    receive() external payable {}
}