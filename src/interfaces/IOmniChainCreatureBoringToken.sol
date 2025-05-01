// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOmniChainCreatureBoringToken
 * @notice Interface for the OmniChainCreatureBoringToken contract
 */
interface IOmniChainCreatureBoringToken {
    /**
     * @notice Initializes the token with custom parameters
     * @param name Token name
     * @param symbol Token symbol
     * @param _protocolFeeDestination Address where protocol fees will be sent
     * @param _protocolBuyFeePercent Protocol buy fee percentage (1e18 = 100%)
     * @param _protocolSellFeePercent Protocol sell fee percentage (1e18 = 100%)
     * @param _battleContract Address of the battle contract
     * @param _signerAddress Address authorized to sign whitelist messages
     * @param _lzEndpoint Address of the LayerZero endpoint
     * @param _stargateRouter Address of the Stargate router
     * @param _homeChainEid EID of the home chain
     * @param _homeFactory Address of the home factory
     */
    function initialize(
        string memory name,
        string memory symbol,
        address _protocolFeeDestination,
        uint256 _protocolBuyFeePercent,
        uint256 _protocolSellFeePercent,
        address _battleContract,
        address _signerAddress,
        address _lzEndpoint,
        address _stargateRouter,
        uint32 _homeChainEid,
        address _homeFactory
    ) external;
    
    /**
     * @notice Transfers ownership of the contract to a new account
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external;
}