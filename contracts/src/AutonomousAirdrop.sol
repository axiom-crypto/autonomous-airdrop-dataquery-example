// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AxiomV2Client } from './AxiomV2Client.sol';
import { IERC20 } from '@openzeppelin-contracts/token/ERC20/IERC20.sol';
import { Ownable } from '@openzeppelin-contracts/access/Ownable.sol';
import { IAxiomV2Input } from './interfaces/IAxiomV2Input.sol';
import { IAxiomV2Query } from './interfaces/IAxiomV2Query.sol';
import { AxiomV2Decoder } from './libraries/AxiomV2Decoder.sol';

contract AutonomousAirdrop is AxiomV2Client, Ownable {
    event ClaimAirdrop(
        address indexed user,
        bytes32 indexed queryHash,
        uint256 numTokens,
        bytes32[] axiomResults
    );
    event ClaimAirdropError(
        address indexed user,
        string error
    );
    event AxiomCallbackQuerySchemaUpdated(bytes32 axiomCallbackQuerySchema);
    event AxiomCallbackCallerAddrUpdated(address axiomCallbackCallerAddr);
    event AirdropTokenAddressUpdated(address token);

    bytes32 public constant SWAP_EVENT_SCHEMA = 0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67;
    address public constant UNI_UNIV_ROUTER_ADDR = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;

    uint64 public callbackSourceChainId;
    address public axiomCallbackCallerAddr;
    bytes32 public axiomCallbackQuerySchema;
    mapping(address => bool) public querySubmitted;
    mapping(address => bool) public hasClaimed;

    IERC20 public token;

    constructor(
        address _axiomV2QueryAddress,
        uint64 _callbackSourceChainId,
        bytes32 _axiomCallbackQuerySchema
    ) AxiomV2Client(_axiomV2QueryAddress) {
        callbackSourceChainId = _callbackSourceChainId;
        axiomCallbackCallerAddr = address(this);
        axiomCallbackQuerySchema = _axiomCallbackQuerySchema;
    }

    function updateCallbackQuerySchema(
        bytes32 _axiomCallbackQuerySchema
    ) public onlyOwner {
        axiomCallbackQuerySchema = _axiomCallbackQuerySchema;
        emit AxiomCallbackQuerySchemaUpdated(_axiomCallbackQuerySchema);
    }

    function updateCallbackCallerAddr(address _axiomCallbackCallerAddr) public onlyOwner {
        axiomCallbackCallerAddr = _axiomCallbackCallerAddr;
        emit AxiomCallbackCallerAddrUpdated(_axiomCallbackCallerAddr);
    }

    function updateAirdropToken(address _token) public onlyOwner {
        token = IERC20(_token);
        emit AirdropTokenAddressUpdated(_token);
    }

    function claimAirdrop(
        IAxiomV2Input.AxiomV2QueryData calldata axiomData
    ) external payable {
        require(!hasClaimed[msg.sender], "User has already claimed this airdrop");
        require(!querySubmitted[msg.sender], "Query has already been submitted");

        address user = abi.decode(axiomData.callback.callbackExtraData, (address));
        require(user == msg.sender, "Address sent in callbackExtraData must be the same as the caller");

        _validateDataQuery(axiomData.dataQuery);
        
        querySubmitted[msg.sender] = true;
        bytes32 queryHash = IAxiomV2Query(axiomV2QueryAddress).sendQuery{ value: msg.value }(
            axiomData.sourceChainId,
            axiomData.dataQueryHash,
            axiomData.computeQuery,
            axiomData.callback,
            axiomData.maxFeePerGas,
            axiomData.callbackGasLimit,
            axiomData.dataQuery
        );
    }

    function _axiomV2Callback(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema,
        bytes32 queryHash,
        bytes32[] calldata axiomResults,
        bytes calldata callbackExtraData
    ) internal virtual override {
        // Parse the submitted user address from the callbackExtraData
        address user = abi.decode(callbackExtraData, (address));

        // Parse results
        bytes32 eventSchema = axiomResults[0];
        address userEventAddress = address(uint160(uint256(axiomResults[1])));
        uint32 blockNumber = uint32(uint256(axiomResults[2]));
        address uniswapUniversalRouterAddr = address(uint160(uint256(axiomResults[3])));

        // Handle results
        if (eventSchema != SWAP_EVENT_SCHEMA) {
            querySubmitted[user] = false;
            emit ClaimAirdropError(
                user,
                "Invalid event schema"
            );
            return;
        } 
        if (userEventAddress != user) {
            querySubmitted[user] = false;
            emit ClaimAirdropError(
                user,
                "Invalid user address for event"
            );
            return;
        }
        if (blockNumber < 9000000) {
            querySubmitted[user] = false;
            emit ClaimAirdropError(
                user,
                "Block number for transaction receipt must be 9000000 or greater"
            );
            return;
        }
        if (uniswapUniversalRouterAddr != UNI_UNIV_ROUTER_ADDR) {
            querySubmitted[user] = false;
            emit ClaimAirdropError(
                user,
                "Transaction `to` address is not the Uniswap Universal Router address"
            );
            return;
        }

        // Transfer tokens to user
        hasClaimed[user] = true;
        uint256 numTokens = 100 * 10**18;
        token.transfer(user, numTokens);

        emit ClaimAirdrop(
            user,
            queryHash,
            numTokens,
            axiomResults
        );
    }

    function _validateDataQuery(bytes calldata dataQuery) internal view {
        // Decode all of the Subqueries from the DataQuery
        (AxiomV2Decoder.DataQueryHeader memory header, bytes calldata dq0) = AxiomV2Decoder.decodeDataQueryHeader(dataQuery);
        (AxiomV2Decoder.ReceiptSubquery memory receiptSq0, bytes calldata dq1) = AxiomV2Decoder.decodeReceiptSubquery(dq0);
        (AxiomV2Decoder.ReceiptSubquery memory receiptSq1, bytes calldata dq2) = AxiomV2Decoder.decodeReceiptSubquery(dq1);
        (AxiomV2Decoder.ReceiptSubquery memory receiptSq2, bytes calldata dq3) = AxiomV2Decoder.decodeReceiptSubquery(dq2);
        (AxiomV2Decoder.TxSubquery memory txSq0, ) = AxiomV2Decoder.decodeTxSubquery(dq3);

        // Validate that this query is only for the chain that this contract is deployed on
        require(header.sourceChainId == block.chainid, "DataQuery sourceChainId be the same as the deployed contract's chainId");
        
        // Check that the types for all of the incoming Subqueries are correct
        require(receiptSq0.subqueryType == uint16(AxiomV2Decoder.SubqueryType.Receipt), "receiptSq0.subqueryType must be 5");
        require(receiptSq1.subqueryType == uint16(AxiomV2Decoder.SubqueryType.Receipt), "receiptSq0.subqueryType must be 5");
        require(receiptSq2.subqueryType == uint16(AxiomV2Decoder.SubqueryType.Receipt), "receiptSq0.subqueryType must be 5");
        require(txSq0.subqueryType == uint16(AxiomV2Decoder.SubqueryType.Tx), "txSq0.subqueryType must be 4");

        // Check txHashes for all Receipt and Tx Subqueries match
        require(keccak256(abi.encode(receiptSq0.txHash)) == keccak256(abi.encode(receiptSq1.txHash)), "txHashes[0,1] for dataQuery do not match");
        require(keccak256(abi.encode(receiptSq1.txHash)) == keccak256(abi.encode(receiptSq2.txHash)), "txHashes[1,2] for dataQuery do not match");
        require(keccak256(abi.encode(receiptSq2.txHash)) == keccak256(abi.encode(txSq0.txHash)), "txHashes[3,4] for dataQuery do not match");
    }

    function _validateAxiomV2Call(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema
    ) internal virtual override {
        require(sourceChainId == callbackSourceChainId, "AxiomV2: caller sourceChainId mismatch");
        require(callerAddr == axiomCallbackCallerAddr, "AxiomV2: caller address mismatch");
        require(querySchema == axiomCallbackQuerySchema, "AxiomV2: query schema mismatch");
    }
}
