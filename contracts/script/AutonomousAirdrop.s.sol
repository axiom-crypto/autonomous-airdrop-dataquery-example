// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import { AutonomousAirdrop } from '../src/AutonomousAirdrop.sol';
import { UselessToken } from '../src/UselessToken.sol';

contract AutonomousAirdropScript is Script {
    address public constant AXIOM_V2_QUERY_GOERLI_ADDR = 0x28CeE427fCD58e5EF1cE4C93F877b621E2Db66df;
    bytes32 public constant DATA_QUERY_QUERY_SCHEMA = bytes32(0);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        AutonomousAirdrop aa = new AutonomousAirdrop(
            AXIOM_V2_QUERY_GOERLI_ADDR,
            5,
            DATA_QUERY_QUERY_SCHEMA
        );

        UselessToken ut = new UselessToken(address(aa));
        aa.updateAirdropToken(address(ut));

        vm.stopBroadcast();
    }
}
