// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRemoteCreatureBoringToken
 * @notice Interface for the RemoteCreatureBoringToken contract
 */
interface IRemoteCreatureBoringToken {
    /**
     * @notice Initializes the token with custom parameters
     * @param name Token name
     * @param symbol Token symbol
     * @param _homeTokenAddress Home token address
     * @param _homeChainEid EID of the home chain
     * @param _lzEndpoint Address of the LayerZero endpoint
     * @param _stargateRouter Address of the Stargate router
     */
    function initialize(
        string memory name,
        string memory symbol,
        address _homeTokenAddress,
        uint32 _homeChainEid,
        address _lzEndpoint,
        address _stargateRouter
    ) external;
    
    /**
     * @notice Transfers ownership of the contract to a new account
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external;
}