pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./StargateHelper.sol";
import "./interfaces/IStargate.sol";
import "lib/LayerZero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol";

// Interface for Remote Factory
interface IRemoteCreatureBoringFactory {
    function isCreatureBoringToken(address token) external view returns (bool);
}

/// @title RemoteCreatureBoringToken - Remote chain token with cross-chain capabilities
/// @author Monsters.fun Team
/// @notice This is a simplified version of the token for remote chains
/// @dev Implements ERC20 with cross-chain messaging to the home token
contract RemoteCreatureBoringToken is 
    Initializable, 
    ERC20Upgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ============ State Variables ============

    /// @notice Home token address on home chain (as bytes32)
    bytes32 public homeTokenAddress;
    
    /// @notice Home chain EID
    uint32 public homeChainEid;
    
    /// @notice Stargate router address
    address public stargateRouter;
    
    /// @notice Factory that created this token
    address public factory;
    
    /// @notice Trading configuration
    bool public buyingActive;
    bool public sellingActive;
    
    /// @notice Mapping of pending operations by nonce
    mapping(uint256 => bool) public pendingOperations;
    
    /// @notice Nonce counter for operations
    uint256 public nonce;

    // ============ Events ============

    event BuyInitiated(address indexed buyer, uint256 ethAmount, uint256 nonce);
    event SellInitiated(address indexed seller, uint256 tokenAmount, uint256 nonce);
    event TokensMinted(address indexed to, uint256 amount);
    event EthTransferred(address indexed to, uint256 amount);

    // ============ Modifiers ============
    
    /// @notice Only factory can call certain functions
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory");
        _;
    }

    // ============ Initializer ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the token with custom parameters
     * @param name Token name
     * @param symbol Token symbol
     * @param _homeTokenAddress Home token address as bytes32
     * @param _homeChainEid EID of the home chain
     * @param _stargateRouter Address of the Stargate router
     * @param _factory Address of the factory
     */
    function initialize(
        string memory name,
        string memory symbol,
        bytes32 _homeTokenAddress,
        uint32 _homeChainEid,
        address _stargateRouter,
        address _factory
    ) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        require(_homeTokenAddress != bytes32(0), "Invalid home token");
        require(_homeChainEid != 0, "Invalid home chain EID");
        require(_stargateRouter != address(0), "Invalid stargate router");
        require(_factory != address(0), "Invalid factory");
        
        homeTokenAddress = _homeTokenAddress;
        homeChainEid = _homeChainEid;
        stargateRouter = _stargateRouter;
        factory = _factory;
        
        // Default to active
        buyingActive = true;
        sellingActive = true;
    }

    // ============ Cross-Chain Trading Functions ============

    /**
     * @notice Buy tokens by sending ETH to home chain
     * @param maxSlippage Maximum slippage percentage (1e18 = 100%)
     * @param deadline Transaction deadline timestamp
     */
    function buyTokens(
        uint256 maxSlippage,
        uint256 deadline
    ) external payable whenNotPaused nonReentrant {
        require(buyingActive, "Buying is not active");
        require(msg.value > 0, "Zero value not allowed");
        require(block.timestamp <= deadline, "Transaction expired");
        
        uint256 currentNonce = nonce++;
        pendingOperations[currentNonce] = true;
        
        // Bridge ETH to home chain
        _bridgeToHomeChain(msg.value, true, currentNonce);
        
        emit BuyInitiated(msg.sender, msg.value, currentNonce);
    }
    
    /**
     * @notice Sell tokens by sending message to home chain
     * @param amount Amount of tokens to sell
     * @param minETHAmount Minimum ETH amount to receive
     * @param deadline Transaction deadline timestamp
     */
    function sellTokens(
        uint256 amount,
        uint256 minETHAmount,
        uint256 deadline
    ) external whenNotPaused nonReentrant {
        require(sellingActive, "Selling is not active");
        require(amount > 0, "Zero amount not allowed");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(block.timestamp <= deadline, "Transaction expired");
        
        uint256 currentNonce = nonce++;
        pendingOperations[currentNonce] = true;
        
        // Burn tokens first
        _burn(msg.sender, amount);
        
        // Send message to home chain for processing
        _sendSellMessage(amount, minETHAmount, currentNonce);
        
        emit SellInitiated(msg.sender, amount, currentNonce);
    }
    
    /**
     * @notice Mint tokens from home chain response (only callable by factory)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mintFromHome(address to, uint256 amount) external onlyFactory {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @notice Transfer ETH from home chain response (only callable by factory)
     * @param to Address to transfer ETH to
     * @param amount Amount of ETH to transfer
     */
    function transferEthFromHome(address to, uint256 amount) external onlyFactory {
        _transferValue(to, amount);
        emit EthTransferred(to, amount);
    }

    // ============ Admin Functions ============

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setBuyingActive(bool _buyingActive) external onlyOwner {
        buyingActive = _buyingActive;
    }

    function setSellingActive(bool _sellingActive) external onlyOwner {
        sellingActive = _sellingActive;
    }
    
    function setStargateRouter(address _stargateRouter) external onlyOwner {
        require(_stargateRouter != address(0), "Invalid stargate router");
        stargateRouter = _stargateRouter;
    }
    
    /// @notice Function that authorizes upgrades
    /// @dev Only callable by owner
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ Internal Functions ============

    /**
     * @notice Bridge ETH to home chain
     * @param ethAmount Amount of ETH to bridge
     * @param isBuy Whether this is a buy operation
     * @param operationNonce Nonce for this operation
     */
    function _bridgeToHomeChain(
        uint256 ethAmount,
        bool isBuy,
        uint256 operationNonce
    ) internal {
        // Create a message with sender info and operation details
        bytes memory composeMsg = abi.encodePacked(
            isBuy ? bytes4(keccak256("CROSS_CHAIN_BUY")) : bytes4(keccak256("CROSS_CHAIN_SELL")),
            abi.encode(msg.sender, ethAmount, operationNonce)
        );
        
        // Create options with compose gas limit
        bytes memory extraOptions = OptionsBuilder.newOptions();
        extraOptions = OptionsBuilder.addExecutorLzComposeOption(
            extraOptions,
            0,       // index
            250_000, // gas
            0        // value
        );
        
        // Create the send parameters
        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: homeChainEid,
            to: homeTokenAddress,
            amountLD: ethAmount,   // Amount of ETH to bridge
            minAmountLD: ethAmount * 95 / 100, // Accept 5% slippage
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: StargateHelper.taxiCmd() // Use taxi for immediate delivery
        });
        
        // Get messaging fee
        IStargate stargate = IStargate(stargateRouter);
        
        try stargate.quoteOFT(sendParam) returns (
            OFTLimit memory,
            OFTFeeDetail[] memory,
            IOFT.OFTReceipt memory receipt
        ) {
            // Update min amount based on quote
            sendParam.minAmountLD = receipt.amountReceivedLD;
            
            // Get messaging fee
            IOFT.MessagingFee memory fee = stargate.quoteSend(sendParam, false);
            
            // Send the ETH with proper value
            try stargate.sendToken{value: ethAmount + fee.nativeFee}(
                sendParam,
                fee,
                msg.sender // Refund address
            ) returns (
                IOFT.MessagingReceipt memory msgReceipt,
                IOFT.OFTReceipt memory,
                Ticket memory
            ) {
                // Successfully initiated the cross-chain operation
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Bridge failed: ", reason)));
            } catch {
                revert("Bridge transaction failed");
            }
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Quote failed: ", reason)));
        } catch {
            revert("Quote failed");
        }
    }
    
    /**
     * @notice Send sell message to home chain
     * @param tokenAmount Amount of tokens sold
     * @param minETHAmount Minimum ETH to receive
     * @param operationNonce Nonce for this operation
     */
    function _sendSellMessage(
        uint256 tokenAmount,
        uint256 minETHAmount,
        uint256 operationNonce
    ) internal {
        // Create message with sell details
        bytes memory sellMsg = abi.encodePacked(
            bytes4(keccak256("CROSS_CHAIN_SELL")),
            abi.encode(msg.sender, tokenAmount, minETHAmount, operationNonce)
        );
        
        // Create options with compose gas limit
        bytes memory extraOptions = OptionsBuilder.newOptions();
        extraOptions = OptionsBuilder.addExecutorLzComposeOption(
            extraOptions,
            0,       // index
            250_000, // gas
            0        // value
        );
        
        // Create the send parameters
        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: homeChainEid,
            to: homeTokenAddress,
            amountLD: 0,           // No ETH being sent
            minAmountLD: 0,
            extraOptions: extraOptions,
            composeMsg: sellMsg,
            oftCmd: StargateHelper.taxiCmd() // Use taxi for immediate delivery
        });
        
        // Get messaging fee
        IStargate stargate = IStargate(stargateRouter);
        IOFT.MessagingFee memory fee = stargate.quoteSend(sendParam, false);
        
        // Send the message
        try stargate.send{value: fee.nativeFee}(
            sendParam,
            fee,
            msg.sender // Refund address
        ) returns (
            IOFT.MessagingReceipt memory,
            IOFT.OFTReceipt memory
        ) {
            // Successfully initiated the cross-chain operation
        } catch Error(string memory reason) {
            // If message fails, re-mint the tokens to user
            _mint(msg.sender, tokenAmount);
            revert(string(abi.encodePacked("Sell failed: ", reason)));
        } catch {
            // If message fails, re-mint the tokens to user
            _mint(msg.sender, tokenAmount);
            revert("Sell transaction failed");
        }
    }
    
    /**
     * @dev Transfers ETH value
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _transferValue(address to, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "Transfer failed");
        }
    }

    /// @notice Allows contract to receive ETH
    receive() external payable {}
}