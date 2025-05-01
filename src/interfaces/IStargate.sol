// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import V2 interfaces based on the documentation
interface IOFT {
    struct SendParam {
        uint32 dstEid;         // Destination endpoint ID
        bytes32 to;            // Recipient address
        uint256 amountLD;      // Amount to send in local decimals
        uint256 minAmountLD;   // Minimum amount to send in local decimals
        bytes extraOptions;    // Additional options for the LayerZero message
        bytes composeMsg;      // The composed message for the send() operation
        bytes oftCmd;          // The OFT command to be executed (taxi, bus, etc.)
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    function quoteOFT(
        SendParam calldata _sendParam
    ) external view returns (
        OFTLimit memory limit,
        OFTFeeDetail[] memory oftFeeDetails,
        OFTReceipt memory receipt
    );

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee);

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    function token() external view returns (address);
}

struct OFTLimit {
    uint256 minAmountLD;
    uint256 maxAmountLD;
}

struct OFTFeeDetail {
    int256 feeAmountLD;
    string description;
}

enum StargateType {
    Pool,
    OFT
}

struct Ticket {
    uint56 ticketId;
    bytes passenger;
}

interface IStargate is IOFT {
    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket);

    function stargateType() external pure returns (StargateType);
}