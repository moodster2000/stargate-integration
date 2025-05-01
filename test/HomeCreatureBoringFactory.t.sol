// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "../src/HomeCreatureBoringFactory.sol";
// import "../src/RemoteCreatureBoringToken.sol";

// interface IRemoteCreatureBoringTokenTest {
//     function name() external view returns (string memory);
//     function symbol() external view returns (string memory);
//     function owner() external view returns (address);
//     function protocolFeeDestination() external view returns (address);
//     function protocolBuyFeePercent() external view returns (uint256);
//     function protocolSellFeePercent() external view returns (uint256);
//     function battleContract() external view returns (address);
//     function signerAddress() external view returns (address);
//     function lzEndpoint() external view returns (address);
//     function homeChainEid() external view returns (uint32);
//     function factoryAddress() external view returns (address);
// }

// // Mock contract for testing upgrades
// contract HomeCreatureBoringFactoryV2 is HomeCreatureBoringFactory {
//     // New variable to demonstrate upgrade
//     bool public v2Enabled;
    
//     // New function to demonstrate upgrade
//     function enableV2() external onlyOwner {
//         v2Enabled = true;
//     }
    
//     // Function to demonstrate upgrade
//     function getVersion() external pure returns (string memory) {
//         return "V2";
//     }
// }

// // Mock LayerZero Endpoint contract for testing
// contract MockLZEndpoint {
//     // Add necessary functions that might be called during initialization
//     function estimateFees(
//         uint32,
//         address,
//         bytes memory,
//         bool,
//         bytes memory
//     ) external pure returns (uint256, uint256) {
//         return (0, 0);
//     }
    
//     function send(
//         uint16,
//         bytes memory,
//         bytes memory,
//         address,
//         address,
//         bytes memory
//     ) external payable returns (bytes memory) {
//         return "";
//     }
// }

// // Create a mock token implementation for testing
// contract MockRemoteCreatureBoringToken is RemoteCreatureBoringToken {
//     // Override initialize to make it simpler for testing
//     function initialize(
//         string memory name_,
//         string memory symbol_,
//         address _protocolFeeDestination,
//         uint256 _protocolBuyFeePercent,
//         uint256 _protocolSellFeePercent,
//         address _battleContract,
//         address _signerAddress,
//         address _lzEndpoint,
//         uint32 _homeChainEid,
//         address _factoryAddress
//     ) public override initializer {
//         __Ownable_init(msg.sender);
//         __ReentrancyGuard_init();
//         __Pausable_init();
//         __UUPSUpgradeable_init();
//         __ERC20_init(name_, symbol_);
        
//         protocolFeeDestination = _protocolFeeDestination;
//         protocolBuyFeePercent = _protocolBuyFeePercent;
//         protocolSellFeePercent = _protocolSellFeePercent;
//         battleContract = _battleContract;
//         signerAddress = _signerAddress;
//         homeChainEid = _homeChainEid;
//     }
// }

// contract HomeCreatureBoringFactoryTest is Test {
//     HomeCreatureBoringFactory public factoryImplementation;
//     HomeCreatureBoringFactory public factory;
//     MockRemoteCreatureBoringToken public tokenImplementation;
//     address public owner;
//     address public feeDestination;
//     uint256 public initialBuyFeePercent;
//     uint256 public initialSellFeePercent;
//     address public battleContract;
//     address public signerAddress;
//     address public lzEndpoint;
//     uint32 public homeChainEid;
    
//     // Test addresses
//     address public alice = address(0x1);
//     address public bob = address(0x2);
//     address public charlie = address(0x3);

//     function setUp() public {
//         owner = address(this);
//         feeDestination = address(0x999);
//         signerAddress = address(0x777);
//         battleContract = address(0x888);
//         initialBuyFeePercent = 0.01 ether; // 1%
//         initialSellFeePercent = 0.02 ether; // 2%
//         homeChainEid = 1; // Example EID for Ethereum mainnet

//         // Deploy mock LZ endpoint
//         MockLZEndpoint mockEndpoint = new MockLZEndpoint();
//         lzEndpoint = address(mockEndpoint);

//         // Deploy token implementation
//         tokenImplementation = new MockRemoteCreatureBoringToken();

//         // Deploy factory implementation
//         factoryImplementation = new HomeCreatureBoringFactory();
        
//         // Deploy proxy and initialize factory
//         bytes memory initData = abi.encodeWithSelector(
//             HomeCreatureBoringFactory.initialize.selector,
//             feeDestination,
//             initialBuyFeePercent,
//             initialSellFeePercent,
//             signerAddress,
//             address(tokenImplementation),
//             lzEndpoint
//         );
        
//         ERC1967Proxy proxy = new ERC1967Proxy(
//             address(factoryImplementation),
//             initData
//         );
        
//         factory = HomeCreatureBoringFactory(payable(address(proxy)));
//         factory.setBattleContract(battleContract);
//     }

//     function testInitialState() public {
//         assertEq(factory.protocolFeeDestination(), feeDestination);
//         assertEq(factory.protocolBuyFeePercent(), initialBuyFeePercent);
//         assertEq(factory.protocolSellFeePercent(), initialSellFeePercent);
//         assertEq(factory.signerAddress(), signerAddress);
//         assertEq(factory.battleContract(), battleContract);
//         assertEq(factory.owner(), owner);
//         assertEq(factory.tokenImplementation(), address(tokenImplementation));
//         assertEq(factory.lzEndpoint(), lzEndpoint);
//     }

//     function testCreateCreatureBoringToken() public {
//         vm.recordLogs();
        
//         // Create token as owner
//         string memory tokenName = "TestCreature";
//         string memory tokenSymbol = "TCRT";
//         factory.createCreatureBoringToken(tokenName, tokenSymbol, homeChainEid);
        
//         // Check for TokenCreated event
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         bytes32 eventSignature = keccak256("TokenCreated(address,string,string)");
//         address tokenAddress;
        
//         for (uint i = 0; i < entries.length; i++) {
//             if (entries[i].topics[0] == eventSignature) {
//                 // Parse the token address from the event data
//                 (tokenAddress, , ) = abi.decode(entries[i].data, (address, string, string));
//                 break;
//             }
//         }
        
//         // Verify token was created
//         assertTrue(tokenAddress != address(0), "Token address should not be zero");
//         assertTrue(factory.isCreatureBoringToken(tokenAddress), "Token should be registered in factory");
//     }

//     function test_RevertWhen_NonOwnerCreatesToken() public {
//         vm.prank(alice);
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.createCreatureBoringToken("TestCreature", "TCRT", homeChainEid);
//     }

//     function testUpdateProtocolFeeDestination() public {
//         address newFeeDestination = address(0x444);
        
//         factory.setProtocolFeeDestination(newFeeDestination);
//         assertEq(factory.protocolFeeDestination(), newFeeDestination);
//     }

//     function testUpdateProtocolBuyFeePercent() public {
//         uint256 newFeePercent = 0.02 ether; // 2%
        
//         factory.setProtocolBuyFeePercent(newFeePercent);
//         assertEq(factory.protocolBuyFeePercent(), newFeePercent);
//     }

//     function testUpdateProtocolSellFeePercent() public {
//         uint256 newFeePercent = 0.03 ether; // 3%
        
//         factory.setProtocolSellFeePercent(newFeePercent);
//         assertEq(factory.protocolSellFeePercent(), newFeePercent);
//     }

//     function testUpdateSignerAddress() public {
//         address newSignerAddress = address(0x999);
        
//         factory.setSignerAddress(newSignerAddress);
//         assertEq(factory.signerAddress(), newSignerAddress);
//     }

//     function testUpdateBattleContract() public {
//         address newBattleContract = address(0x777);
        
//         factory.setBattleContract(newBattleContract);
//         assertEq(factory.battleContract(), newBattleContract);
//     }

//     function testUpdateLzEndpoint() public {
//         address newLzEndpoint = address(0x555);
        
//         factory.setLzEndpoint(newLzEndpoint);
//         assertEq(factory.lzEndpoint(), newLzEndpoint);
//     }

//     function testUpdateTokenImplementation() public {
//         // Deploy a new token implementation
//         MockRemoteCreatureBoringToken newImplementation = new MockRemoteCreatureBoringToken();
        
//         // Update token implementation
//         factory.setTokenImplementation(address(newImplementation));
        
//         // Verify update
//         assertEq(factory.tokenImplementation(), address(newImplementation));
        
//         // Record logs and create a token with the new implementation
//         vm.recordLogs();
//         factory.createCreatureBoringToken("NewImplementationToken", "NIT", homeChainEid);
        
//         // Verify token was created by checking event emission
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         bytes32 eventSignature = keccak256("TokenCreated(address,string,string)");
//         bool eventFound = false;
        
//         for (uint i = 0; i < entries.length; i++) {
//             if (entries[i].topics[0] == eventSignature) {
//                 eventFound = true;
//                 break;
//             }
//         }
        
//         assertTrue(eventFound, "TokenCreated event should be emitted");
//     }

//     function testPauseUnpause() public {
//         // Test pause
//         factory.pause();
//         assertTrue(factory.paused());

//         // Try to create token while paused
//         vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
//         factory.createCreatureBoringToken("TestCreature", "TCRT", homeChainEid);

//         // Test unpause
//         factory.unpause();
//         assertFalse(factory.paused());

//         // Record logs and create token after unpause
//         vm.recordLogs();
//         factory.createCreatureBoringToken("TestCreature", "TCRT", homeChainEid);
        
//         // Verify token was created by checking event emission
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         bytes32 eventSignature = keccak256("TokenCreated(address,string,string)");
//         bool eventFound = false;
        
//         for (uint i = 0; i < entries.length; i++) {
//             if (entries[i].topics[0] == eventSignature) {
//                 eventFound = true;
//                 break;
//             }
//         }
        
//         assertTrue(eventFound, "TokenCreated event should be emitted after unpause");
//     }

//     function testInvalidChainEid() public {
//         // Use a valid EID since there's no validation in the contract
//         // We'll just verify that the token can be created with any EID
//         uint32 someEid = 0;
        
//         vm.recordLogs();
//         factory.createCreatureBoringToken("TestCreature", "TCRT", someEid);
        
//         // Verify token was created
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         bytes32 eventSignature = keccak256("TokenCreated(address,string,string)");
//         bool eventFound = false;
        
//         for (uint i = 0; i < entries.length; i++) {
//             if (entries[i].topics[0] == eventSignature) {
//                 eventFound = true;
//                 break;
//             }
//         }
        
//         assertTrue(eventFound, "TokenCreated event should be emitted even with zero EID");
        
//         // Note: If you want to add validation for non-zero EID in the contract,
//         // this test should be modified to expect a revert
//     }

//     function test_RevertWhen_NonOwnerCallsOwnerFunctions() public {
//         vm.startPrank(alice);
        
//         // Try to update fee destination
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setProtocolFeeDestination(address(0x888));

//         // Try to update buy fee percent
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setProtocolBuyFeePercent(0.02 ether);

//         // Try to update sell fee percent
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setProtocolSellFeePercent(0.03 ether);

//         // Try to update signer address
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setSignerAddress(address(0x999));

//         // Try to update battle contract
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setBattleContract(address(0x777));
        
//         // Try to update token implementation
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setTokenImplementation(address(0x555));

//         // Try to update LZ endpoint
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.setLzEndpoint(address(0x444));

//         // Try to pause
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.pause();

//         vm.stopPrank();
//     }

//     function test_RevertWhen_SettingInvalidAddresses() public {
//         // Test setting zero address as fee destination
//         vm.expectRevert("Invalid address");
//         factory.setProtocolFeeDestination(address(0));

//         // Test setting zero address as signer
//         vm.expectRevert("Invalid signer address");
//         factory.setSignerAddress(address(0));
        
//         // Test setting zero address as battle contract
//         vm.expectRevert("Invalid battle contract");
//         factory.setBattleContract(address(0));
        
//         // Test setting zero address as token implementation
//         vm.expectRevert("Invalid implementation");
//         factory.setTokenImplementation(address(0));

//         // Test setting zero address as LZ endpoint
//         vm.expectRevert("Invalid LZ endpoint");
//         factory.setLzEndpoint(address(0));
//     }
    
//     function testUpgradeToV2() public {
//         // Deploy V2 implementation
//         HomeCreatureBoringFactoryV2 newImplementation = new HomeCreatureBoringFactoryV2();
        
//         // Upgrade to V2
//         factory.upgradeToAndCall(address(newImplementation),"");
        
//         // Now cast to V2 to access new functions
//         HomeCreatureBoringFactoryV2 factoryV2 = HomeCreatureBoringFactoryV2(address(factory));
        
//         // Test new function
//         assertFalse(factoryV2.v2Enabled());
//         factoryV2.enableV2();
//         assertTrue(factoryV2.v2Enabled());
        
//         // Test overridden function
//         assertEq(factoryV2.getVersion(), "V2");
        
//         // Test that existing state is preserved
//         assertEq(factoryV2.protocolFeeDestination(), feeDestination);
//         assertEq(factoryV2.protocolBuyFeePercent(), initialBuyFeePercent);
//         assertEq(factoryV2.protocolSellFeePercent(), initialSellFeePercent);
//         assertEq(factoryV2.lzEndpoint(), lzEndpoint);
//     }
    
//     function test_RevertWhen_NonOwnerUpgrades() public {
//         // Deploy V2 implementation
//         HomeCreatureBoringFactoryV2 newImplementation = new HomeCreatureBoringFactoryV2();
        
//         // Try to upgrade as non-owner
//         vm.prank(alice);
//         vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
//         factory.upgradeToAndCall(address(newImplementation),"");
//     }
    
//     function testReinitializationPrevention() public {
//         // Try to initialize again, should revert
//         vm.expectRevert();
//         factory.initialize(
//             feeDestination,
//             initialBuyFeePercent,
//             initialSellFeePercent,
//             signerAddress,
//             address(tokenImplementation),
//             lzEndpoint
//         );
//     }
    
//     function testDirectInitializationPrevention() public {
//         // Try to initialize the implementation directly, should revert
//         vm.expectRevert();
//         factoryImplementation.initialize(
//             feeDestination,
//             initialBuyFeePercent,
//             initialSellFeePercent,
//             signerAddress,
//             address(tokenImplementation),
//             lzEndpoint
//         );
//     }

//     receive() external payable {}
// }