import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can create new campaign",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "click-mint",
        "create-campaign",
        [
          types.utf8("Test Campaign"),
          types.utf8("https://test.com"),
          types.uint(100)
        ],
        wallet_1.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectUint(1);
  },
});

Clarinet.test({
  name: "Ensure can update campaign metrics",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "click-mint",
        "create-campaign",
        [
          types.utf8("Test Campaign"),
          types.utf8("https://test.com"),
          types.uint(100)
        ],
        wallet_1.address
      ),
      Tx.contractCall(
        "click-mint",
        "update-metrics",
        [
          types.uint(1),
          types.uint(1000),
          types.uint(100),
          types.uint(10)
        ],
        wallet_1.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk();
  },
});

Clarinet.test({
  name: "Ensure can transfer campaign ownership",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    const wallet_2 = accounts.get("wallet_2")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "click-mint",
        "create-campaign",
        [
          types.utf8("Test Campaign"),
          types.utf8("https://test.com"),
          types.uint(100)
        ],
        wallet_1.address
      ),
      Tx.contractCall(
        "click-mint",
        "transfer-campaign",
        [
          types.uint(1),
          types.principal(wallet_2.address)
        ],
        wallet_1.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk();
  },
});
