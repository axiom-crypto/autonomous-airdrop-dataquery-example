// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library AxiomV2Decoder {
    enum SubqueryType {
        UnusedTypeStorageV1,  // not used
        Header,
        Account,
        Storage,
        Tx,
        Receipt,
        SolidityNestedMapping
    }

    struct DataQueryHeader {
        uint64 sourceChainId;
        uint16 subqueryLen;
    }

    struct HeaderSubquery {
        uint16 subqueryType;
        uint32 blockNumber;
        uint32 fieldIdx;
    }

    struct AccountSubquery {
        uint16 subqueryType;
        uint32 blockNumber;
        address addr;
        uint32 fieldIdx;
    }

    struct StorageSubquery {
        uint16 subqueryType;
        uint32 blockNumber;
        address addr;
        uint256 slot;
    }

    struct TxSubquery {
        uint16 subqueryType;
        bytes32 txHash;
        uint32 fieldOrCalldataIdx;
    }

    struct ReceiptSubquery {
        uint16 subqueryType;
        bytes32 txHash;
        uint32 fieldOrLogIdx;
        uint32 topicOrDataOrAddressIdx;
        bytes32 eventSchema;
    }

    struct SolidityNestedMappingSubquery {
        uint16 subqueryType;
        uint32 blockNumber;
        address addr;
        uint256 mappingSlot;
        uint8 mappingDepth;
        bytes32[] keys;
    }

    function decodeDataQueryHeader(bytes calldata query) internal pure returns (DataQueryHeader memory, bytes calldata) {
        uint64 sourceChainId = uint64(bytes8(query[0:8]));
        uint16 subqueryLen = uint16(bytes2(query[8:10]));
        return (DataQueryHeader(sourceChainId, subqueryLen), query[10:]);
    }

    function decodeHeaderSubquery(bytes calldata query) internal pure returns (HeaderSubquery memory, bytes calldata) {
        uint16 subqueryType = uint16(bytes2(query[0:2]));
        uint32 blockNumber = uint32(bytes4(query[2:6]));
        uint32 fieldIdx = uint32(bytes4(query[6:10]));
        return (HeaderSubquery(subqueryType, blockNumber, fieldIdx), query[10:]);
    }

    function decodeAccountSubquery(bytes calldata query) internal pure returns (AccountSubquery memory, bytes calldata) {
        uint16 subqueryType = uint16(bytes2(query[0:2]));
        uint32 blockNumber = uint32(bytes4(query[2:6]));
        address addr = address(bytes20(query[6:26]));
        uint32 fieldIdx = uint32(bytes4(query[26:30]));
        return (AccountSubquery(subqueryType, blockNumber, addr, fieldIdx), query[30:]);
    }

    function decodeStorageSubquery(bytes calldata query) internal pure returns (StorageSubquery memory, bytes calldata) {
        uint16 subqueryType = uint16(bytes2(query[0:2]));
        uint32 blockNumber = uint32(bytes4(query[2:6]));
        address addr = address(bytes20(query[6:26]));
        uint256 slot = uint256(bytes32(query[26:58]));
        return (StorageSubquery(subqueryType, blockNumber, addr, slot), query[58:]);
    }

    function decodeTxSubquery(bytes calldata query) internal pure returns (TxSubquery memory, bytes calldata) {
        uint16 subqueryType = uint16(bytes2(query[0:2]));
        bytes32 txHash = bytes32(query[2:34]);
        uint32 fieldOrCalldataIdx = uint32(bytes4(query[34:38]));
        return (TxSubquery(subqueryType, txHash, fieldOrCalldataIdx), query[38:]);
    }

    function decodeReceiptSubquery(bytes calldata query) internal pure returns (ReceiptSubquery memory, bytes calldata) {
        uint16 subqueryType = uint16(bytes2(query[0:2]));
        bytes32 txHash = bytes32(query[2:34]);
        uint32 fieldOrLogIdx = uint32(bytes4(query[34:38]));
        uint32 topicOrDataOrAddressIdx = uint32(bytes4(query[38:42]));
        bytes32 eventSchema = bytes32(query[42:74]);
        return (ReceiptSubquery(subqueryType, txHash, fieldOrLogIdx, topicOrDataOrAddressIdx, eventSchema), query[74:]);
    }

    function decodeSolidityNestedMappingSubquery(bytes calldata query) internal pure returns (SolidityNestedMappingSubquery memory, bytes calldata) {
        uint16 subqueryType = uint16(bytes2(query[0:2]));
        uint32 blockNumber = uint32(bytes4(query[2:6]));
        address addr = address(bytes20(query[6:26]));
        uint256 mappingSlot = uint256(bytes32(query[26:58]));
        uint8 mappingDepth = uint8(bytes1(query[58:59]));
        bytes32[] memory keys = new bytes32[](mappingDepth);
        uint256 offset = 59;
        for (uint256 i = 0; i < mappingDepth; i++) {
            keys[i] = bytes32(query[offset:offset+32]);
            offset += 32;
        }
        return (SolidityNestedMappingSubquery(subqueryType, blockNumber, addr, mappingSlot, mappingDepth, keys), query[offset:]);
    }   
}