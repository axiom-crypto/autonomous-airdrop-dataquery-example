// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import { AutonomousAirdrop } from '../src/AutonomousAirdrop.sol';
import { UselessToken } from '../src/UselessToken.sol';

contract AutonomousAirdropScript is Script {
    address public constant AXIOM_V2_QUERY_GOERLI_MOCK_ADDR = 0xf15cc7B983749686Cd1eCca656C3D3E46407DC1f;
    bytes32 public constant DATA_QUERY_QUERY_SCHEMA = bytes32(0);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        AutonomousAirdrop aa = new AutonomousAirdrop(
            AXIOM_V2_QUERY_GOERLI_MOCK_ADDR,
            5,
            DATA_QUERY_QUERY_SCHEMA
        );

        UselessToken ut = new UselessToken(address(aa));
        aa.updateAirdropToken(address(ut));

        vm.stopBroadcast();
    }
}
