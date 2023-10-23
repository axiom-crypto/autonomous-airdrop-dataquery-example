import { Constants } from '@/shared/constants';
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

export const buildAxiomQuery = async (
  address: string,
  txHash: string,
  blockNumber: number,
  logIdx: number,
) => {
  if (!address || !txHash || !blockNumber || !logIdx) {
    throw new Error("Invalid Uniswap V2 `Swap` event");
  }

  const config: AxiomConfig = {
    providerUri: process.env.PROVIDER_URI_GOERLI as string,
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
    extraData: bytes32(address),
  }
  query.setCallback(callback);

  // Validate the Query
  const isValid = await query.validate();
  console.log("isValid", isValid);

  // Build the Query
  const builtQuery = await query.build();

  // Calculate the payment
  const payment = query.calculateFee();

  return {
    builtQuery,
    payment,
  };
}
