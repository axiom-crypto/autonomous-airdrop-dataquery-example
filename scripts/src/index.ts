import {
  Axiom,
  AxiomConfig,
  AxiomV2Callback,
  QueryV2,
  TxField,
  buildReceiptSubquery,
  buildTxSubquery,
  bytes32,
} from '@axiom-crypto/experimental';
import { ethers } from 'ethers';
import dotenv from 'dotenv';
dotenv.config();

import { abi as AutonomousAirdropAbi } from './abi/AutonomousAirdrop.json';
import { findFirstUniswapTx } from './parseRecentTx';
import { Constants } from './constants';

const privateKey = process.env.PRIVATE_KEY as string;
const provider = new ethers.JsonRpcProvider(process.env.PROVIDER_URI_GOERLI as string);
const wallet = new ethers.Wallet(privateKey, provider);

async function sendQuery(swapEvent: any) {
  console.log("swapEvent", swapEvent);
  const log = swapEvent?.log;
  const txHash = log?.tx_hash;
  const blockNumber = log?.block_height;
  const logIdx = swapEvent?.logIdx;
  if (!txHash || !blockNumber || !logIdx) {
    throw new Error("Invalid Uniswap V2 `Swap` event");
  }

  const autoAirdropContract = new ethers.Contract(
    Constants.AUTO_AIRDROP_ADDR,
    AutonomousAirdropAbi,
    wallet
  );

  const config: AxiomConfig = {
    providerUri: process.env.PROVIDER_URI_GOERLI as string,
    privateKey,
    version: "v2",
    chainId: 5,
    mock: true,
  }
  const axiom = new Axiom(config);
  const query = (axiom.query as QueryV2).new();

  // Append a Receipt Subquery that gets the following event schema:
  // Swap(address,uint256,uint256,uint256,uint256,address)
  // 0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67
  let receiptSubquery = buildReceiptSubquery(txHash)
    .log(logIdx)
    .topic(0) // topic 0: event schema
    .eventSchema(Constants.EVENT_SCHEMA);
  query.appendDataSubquery(receiptSubquery);

  // Append a Receipt Subquery that checks the address recipient field
  receiptSubquery = buildReceiptSubquery(txHash)
    .log(logIdx)
    .topic(2) // topic 2: recipient
    .eventSchema(Constants.EVENT_SCHEMA);
  query.appendDataSubquery(receiptSubquery);

  // Append a Receipt Subquery that gets the block number of the transaction receipt
  receiptSubquery = buildReceiptSubquery(txHash)
    .blockNumber(); // block number of the transaction
  query.appendDataSubquery(receiptSubquery);

  // Append a Transaction Subquery that gets the `to` field of the transaction
  let txSubquery = buildTxSubquery(txHash)
    .field(TxField.To)
  console.log(txSubquery);
  query.appendDataSubquery(txSubquery);

  const callback: AxiomV2Callback = {
    target: Constants.AUTO_AIRDROP_ADDR,
    extraData: bytes32(wallet.address),
  }
  query.setCallback(callback);

  // Validate the Query
  const isValid = await query.validate();
  console.log("isValid", isValid);

  // Build the Query
  const builtQuery = await query.build();

  // Calculate the payment
  const payment = query.calculateFee();

  console.log("dataQuery:", builtQuery.dataQuery);

  // Build the query struct to send to the Airdrop contract
  const axiomQuery = {
    sourceChainId: builtQuery.sourceChainId,
    dataQueryHash: builtQuery.dataQueryHash,
    computeQuery: builtQuery.computeQuery,
    callback: builtQuery.callback,
    userSalt: builtQuery.userSalt,
    maxFeePerGas: builtQuery.maxFeePerGas,
    callbackGasLimit: builtQuery.callbackGasLimit,
    refundee: await wallet.getAddress(),
    dataQuery: builtQuery.dataQuery,
  };
  console.log(axiomQuery);

  const queryId = await query.getQueryId();

  // Submit Query to Airdrop contract
  const tx = await autoAirdropContract.claimAirdrop(
    axiomQuery,
    { value: payment }
  );
  const receipt = await tx.wait();
  console.log(receipt);
  console.log("Query submitted. QueryID:", queryId);
}

async function main() {
  // Get first Uniswap tx for address
  const swapEvent = await findFirstUniswapTx(wallet.address);
  await sendQuery(swapEvent);
}

main();
